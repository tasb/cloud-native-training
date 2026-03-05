# ──────────────────────────────────────────────────────────────────────────────
# Outputs — used by GitHub Actions and post-provisioning steps
# ──────────────────────────────────────────────────────────────────────────────

output "resource_group_name" {
  description = "Resource group containing all training resources"
  value       = azurerm_resource_group.main.name
}

# ─── ACR ──────────────────────────────────────────────────────────────────────

output "acr_name" {
  description = "Azure Container Registry name"
  value       = azurerm_container_registry.main.name
}

output "acr_login_server" {
  description = "ACR login server URL (e.g. acrtraininga1b2c3d4.azurecr.io)"
  value       = azurerm_container_registry.main.login_server
}

# ─── AKS ──────────────────────────────────────────────────────────────────────

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_id" {
  description = "AKS cluster resource ID"
  value       = azurerm_kubernetes_cluster.main.id
}

output "aks_oidc_issuer_url" {
  description = "AKS OIDC issuer URL (for Workload Identity federated credentials)"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "get_credentials_command" {
  description = "Run this to configure kubectl"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name} --overwrite-existing"
}

# ─── Key Vault ────────────────────────────────────────────────────────────────

output "key_vault_name" {
  description = "Azure Key Vault name"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "Azure Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

output "postgresql_password_secret_name" {
  description = "Key Vault secret name holding the PostgreSQL admin password"
  value       = azurerm_key_vault_secret.postgresql_password.name
}

# ─── PostgreSQL ───────────────────────────────────────────────────────────────

output "postgresql_fqdn" {
  description = "PostgreSQL Flexible Server fully-qualified domain name"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "postgresql_admin_username" {
  description = "PostgreSQL administrator username"
  value       = var.postgresql_admin_username
}

output "postgresql_database_name" {
  description = "Application database name"
  value       = azurerm_postgresql_flexible_server_database.app.name
}

# ─── Key Vault CSI Driver identity ───────────────────────────────────────────

output "kv_csi_identity_client_id" {
  description = "Client ID of the Key Vault CSI driver managed identity — use as keyVault.identityClientId in helm/backend"
  value       = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].client_id
}

# ─── GitHub Actions variable summary ─────────────────────────────────────────

output "github_actions_vars" {
  description = "Values to set as GitHub Actions variables (Settings > Secrets and variables > Actions > Variables)"
  value = {
    ACR_NAME                  = azurerm_container_registry.main.name
    ACR_LOGIN_SERVER          = azurerm_container_registry.main.login_server
    AKS_CLUSTER_NAME          = azurerm_kubernetes_cluster.main.name
    AKS_RESOURCE_GROUP        = azurerm_resource_group.main.name
    KEY_VAULT_NAME            = azurerm_key_vault.main.name
    KV_CSI_IDENTITY_CLIENT_ID = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].client_id
    PSQL_FQDN                 = azurerm_postgresql_flexible_server.main.fqdn
    PSQL_ADMIN_USER           = var.postgresql_admin_username
    PSQL_DB_NAME              = azurerm_postgresql_flexible_server_database.app.name
    AZURE_TENANT_ID_VAR       = data.azurerm_client_config.current.tenant_id
  }
}
