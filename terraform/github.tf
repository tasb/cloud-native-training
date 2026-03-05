# ──────────────────────────────────────────────────────────────────────────────
# GitHub Actions Variables
#
# These are set automatically after `terraform apply` so the CI/CD pipelines
# (ci.yml, cd.yml) can reference infrastructure values without manual steps.
#
# Authentication: the GitHub provider reads GITHUB_TOKEN from the environment.
# In GitHub Actions this is automatically available as secrets.GITHUB_TOKEN.
# ──────────────────────────────────────────────────────────────────────────────

resource "github_actions_variable" "acr_name" {
  repository    = var.github_repository
  variable_name = "ACR_NAME"
  value         = azurerm_container_registry.main.name
}

resource "github_actions_variable" "acr_login_server" {
  repository    = var.github_repository
  variable_name = "ACR_LOGIN_SERVER"
  value         = azurerm_container_registry.main.login_server
}

resource "github_actions_variable" "aks_cluster_name" {
  repository    = var.github_repository
  variable_name = "AKS_CLUSTER_NAME"
  value         = azurerm_kubernetes_cluster.main.name
}

resource "github_actions_variable" "aks_resource_group" {
  repository    = var.github_repository
  variable_name = "AKS_RESOURCE_GROUP"
  value         = azurerm_resource_group.main.name
}

resource "github_actions_variable" "key_vault_name" {
  repository    = var.github_repository
  variable_name = "KEY_VAULT_NAME"
  value         = azurerm_key_vault.main.name
}

resource "github_actions_variable" "kv_csi_identity_client_id" {
  repository    = var.github_repository
  variable_name = "KV_CSI_IDENTITY_CLIENT_ID"
  value         = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].client_id
}

resource "github_actions_variable" "psql_fqdn" {
  repository    = var.github_repository
  variable_name = "PSQL_FQDN"
  value         = azurerm_postgresql_flexible_server.main.fqdn
}

resource "github_actions_variable" "psql_admin_user" {
  repository    = var.github_repository
  variable_name = "PSQL_ADMIN_USER"
  value         = var.postgresql_admin_username
}

resource "github_actions_variable" "psql_db_name" {
  repository    = var.github_repository
  variable_name = "PSQL_DB_NAME"
  value         = azurerm_postgresql_flexible_server_database.app.name
}

resource "github_actions_variable" "azure_tenant_id_var" {
  repository    = var.github_repository
  variable_name = "AZURE_TENANT_ID_VAR"
  value         = data.azurerm_client_config.current.tenant_id
}
