# ──────────────────────────────────────────────────────────────────────────────
# Random suffix for globally-unique resource names
# ──────────────────────────────────────────────────────────────────────────────
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  suffix = random_id.suffix.hex # e.g. "a1b2c3d4"
  # Key Vault name: 3–24 alphanumeric + hyphens
  kv_name = "kv-${var.environment}-${local.suffix}"
  # ACR name: 5–50 alphanumeric only
  acr_name = "acr${var.environment}${local.suffix}"
}

# ──────────────────────────────────────────────────────────────────────────────
# Resource Group
# ──────────────────────────────────────────────────────────────────────────────
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Virtual Network
# ──────────────────────────────────────────────────────────────────────────────
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/8"]
  tags                = var.tags
}

# AKS subnet — pod IPs come from here (Azure CNI)
resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.240.0.0/16"]
}

# PostgreSQL subnet — must be delegated to the flexible server service
resource "azurerm_subnet" "postgresql" {
  name                 = "snet-postgresql"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.241.0.0/24"]

  delegation {
    name = "postgresql-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Azure Container Registry
# ──────────────────────────────────────────────────────────────────────────────
resource "azurerm_container_registry" "main" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.acr_sku
  admin_enabled       = false # Use managed identity, not admin credentials
  tags                = var.tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Azure Key Vault
# ──────────────────────────────────────────────────────────────────────────────
resource "azurerm_key_vault" "main" {
  name                       = local.kv_name
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true  # Use RBAC, not legacy access policies
  soft_delete_retention_days = 7
  purge_protection_enabled   = false # Disabled for training; enable in production
  tags                       = var.tags
}

# Current user/SP gets Key Vault Administrator so it can write secrets via Terraform
resource "azurerm_role_assignment" "kv_admin_current_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ──────────────────────────────────────────────────────────────────────────────
# PostgreSQL Admin Password — generated and stored in Key Vault
# ──────────────────────────────────────────────────────────────────────────────
resource "random_password" "postgresql" {
  length           = 24
  special          = true
  override_special = "!#%&*-_=+?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "azurerm_key_vault_secret" "postgresql_password" {
  name         = "postgresql-admin-password"
  value        = random_password.postgresql.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.kv_admin_current_user]
  tags       = var.tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Private DNS Zone for PostgreSQL Flexible Server
# ──────────────────────────────────────────────────────────────────────────────
resource "azurerm_private_dns_zone" "postgresql" {
  name                = "${var.environment}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  name                  = "vnetlink-postgresql"
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  resource_group_name   = azurerm_resource_group.main.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Azure Database for PostgreSQL Flexible Server
# ──────────────────────────────────────────────────────────────────────────────
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "psql-${var.environment}-${local.suffix}"
  location               = azurerm_resource_group.main.location
  resource_group_name    = azurerm_resource_group.main.name
  administrator_login    = var.postgresql_admin_username
  administrator_password = random_password.postgresql.result
  sku_name               = var.postgresql_sku
  storage_mb             = var.postgresql_storage_mb
  version                = var.postgresql_version

  # VNet integration — private connectivity only
  delegated_subnet_id = azurerm_subnet.postgresql.id
  private_dns_zone_id = azurerm_private_dns_zone.postgresql.id

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false # Disable for training

  tags = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgresql]
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "training_db"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Allow connections from AKS subnet
resource "azurerm_postgresql_flexible_server_firewall_rule" "aks_subnet" {
  name      = "allow-aks-subnet"
  server_id = azurerm_postgresql_flexible_server.main.id
  # Private DNS + VNet injection handles connectivity; this rule covers any
  # non-VNet-injected access patterns (e.g. CI runners with public IP).
  # For fully private, remove this rule and rely on VNet integration only.
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0" # Azure services firewall exception
}

# ──────────────────────────────────────────────────────────────────────────────
# AKS Cluster
# ──────────────────────────────────────────────────────────────────────────────
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.environment}-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.environment}-${local.suffix}"
  kubernetes_version  = var.aks_kubernetes_version

  # ─── System Node Pool ───────────────────────────────────────────────────────
  # The default_node_pool does not support spot in azurerm — spot is configured
  # on the separate user node pool below (azurerm_kubernetes_cluster_node_pool).
  # Keep this pool small: it only runs kube-system / Istio control-plane pods.
  default_node_pool {
    name           = "system"
    node_count     = var.aks_system_node_count
    vm_size        = var.aks_vm_size
    vnet_subnet_id = azurerm_subnet.aks.id

    # Taint so only system-critical pods land here; app workloads go to spot pool
    only_critical_addons_enabled = true

    upgrade_settings {
      max_surge = "10%"
    }
  }

  # ─── Identity ───────────────────────────────────────────────────────────────
  identity {
    type = "SystemAssigned"
  }

  # ─── Workload Identity (for pods to authenticate to Azure) ──────────────────
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  # ─── Key Vault Secrets Store CSI Driver ─────────────────────────────────────
  # Allows pods to mount Key Vault secrets as volumes or env vars
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # ─── Azure Policy ───────────────────────────────────────────────────────────
  azure_policy_enabled = true

  # ─── Istio Service Mesh ─────────────────────────────────────────────────────
  service_mesh_profile {
    mode                             = "Istio"
    revisions                        = ["asm-1-22"]
    internal_ingress_gateway_enabled = true
    external_ingress_gateway_enabled = false # Internal only for training
  }

  # ─── Networking (Azure CNI) ─────────────────────────────────────────────────
  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    # service_cidr must not overlap with the VNet (10.0.0.0/8) or node/pod ranges
    service_cidr   = "172.16.0.0/16"
    dns_service_ip = "172.16.0.10"
  }

  tags = var.tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Spot User Node Pool
# Application workloads run here. Spot VMs reduce cost by up to 90%.
# Pods must tolerate: kubernetes.azure.com/scalesetpriority=spot:NoSchedule
# ──────────────────────────────────────────────────────────────────────────────
resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  name                  = "spot"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.aks_spot_vm_size
  vnet_subnet_id        = azurerm_subnet.aks.id
  mode                  = "User"

  # Spot configuration
  priority        = "Spot"
  eviction_policy = "Delete"
  spot_max_price  = -1 # -1 = capped at on-demand price

  # Auto-scaling — scale to 0 when idle to maximise savings
  auto_scaling_enabled = true
  min_count            = var.aks_spot_min_count
  max_count            = var.aks_spot_max_count

  # Standard AKS spot label + taint set automatically by Azure;
  # declaring them explicitly keeps Terraform state consistent.
  node_labels = {
    "kubernetes.azure.com/scalesetpriority" = "spot"
  }
  node_taints = [
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule",
  ]

  upgrade_settings {
    max_surge = "10%"
  }

  tags = var.tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Role Assignments
# ──────────────────────────────────────────────────────────────────────────────

# AKS kubelet identity → ACR: pull images without admin credentials
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}

# AKS Key Vault CSI driver identity → Key Vault: read secrets
resource "azurerm_role_assignment" "aks_kv_secrets_user" {
  principal_id                     = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].object_id
  role_definition_name             = "Key Vault Secrets User"
  scope                            = azurerm_key_vault.main.id
  skip_service_principal_aad_check = true
}

# AKS system-assigned identity → Contributor on its own node resource group
# (AKS needs this to manage node infrastructure)
resource "azurerm_role_assignment" "aks_network_contributor" {
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
  role_definition_name = "Network Contributor"
  scope                = azurerm_virtual_network.main.id
}
