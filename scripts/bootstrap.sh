#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# bootstrap.sh — Prepare Azure + GitHub for Terraform / GitHub Actions CI/CD
#
# What this script does (idempotent — safe to run multiple times):
#   1. Creates a resource group for bootstrap resources
#   2. Creates an Azure Storage Account + container for Terraform remote state
#   3. Creates a User-Assigned Managed Identity (UAMI) for GitHub Actions OIDC
#   4. Assigns the minimum required roles to the UAMI
#   5. Creates federated credentials for each GitHub Actions trigger
#   6. Sets GitHub Actions secrets (AZURE_CLIENT_ID, AZURE_TENANT_ID, ...)
#   7. Sets GitHub Actions variables (TF_BACKEND_*, TF_VAR_*, ACR_*, ...)
#   8. Creates GitHub environments (production, pull-request)
#
# Prerequisites:
#   - Azure CLI >= 2.50   (az --version)
#   - GitHub CLI >= 2.40  (gh --version)
#   - jq                  (brew install jq  /  apt install jq)
#   - Logged in to Azure as Owner on the target subscription  (az login)
#   - Logged in to GitHub CLI with repo scope  (gh auth login)
#
# Usage:
#   chmod +x scripts/bootstrap.sh
#   ./scripts/bootstrap.sh
#
#   # Or override defaults via env vars (no prompts):
#   GITHUB_ORG=my-org SNYK_TOKEN=snyk_xxx ./scripts/bootstrap.sh
# ──────────────────────────────────────────────────────────────────────────────

set -uo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}═══ $* ═══${RESET}"; }

# ──────────────────────────────────────────────────────────────────────────────
# CONFIGURATION — override via environment variables or edit defaults below
# ──────────────────────────────────────────────────────────────────────────────

GITHUB_ORG="${GITHUB_ORG:-tasb}"
GITHUB_REPO="${GITHUB_REPO:-cloud-native-training}"

LOCATION="${LOCATION:-westeurope}"

# Resource group that holds the UAMI and Terraform state storage account.
BOOTSTRAP_RG="${BOOTSTRAP_RG:-rg-tf-bootstrap}"

# Terraform state storage (3–24 lowercase alphanum, globally unique).
# Leave empty to auto-generate from subscription ID.
TF_STATE_SA="${TF_STATE_SA:-}"
TF_STATE_CONTAINER="${TF_STATE_CONTAINER:-tfstate}"

# Terraform variables forwarded to GitHub Actions
TF_VAR_RG_NAME="${TF_VAR_RG_NAME:-rg-cloud-native-training}"
TF_VAR_ENVIRONMENT="${TF_VAR_ENVIRONMENT:-training}"

# User-Assigned Managed Identity name
IDENTITY_NAME="${IDENTITY_NAME:-uami-github-actions}"

# Snyk token — set here or export SNYK_TOKEN before running.
# If empty the script will prompt interactively.
SNYK_TOKEN="${SNYK_TOKEN:-}"

# ──────────────────────────────────────────────────────────────────────────────
# PRE-FLIGHT CHECKS
# ──────────────────────────────────────────────────────────────────────────────

header "Pre-flight checks"

command -v az  &>/dev/null || error "Azure CLI not found. Install: https://aka.ms/installazurecli"
command -v gh  &>/dev/null || error "GitHub CLI not found. Install: https://cli.github.com"
command -v jq  &>/dev/null || error "jq not found. Install: brew install jq  or  apt install jq"

az account show &>/dev/null || error "Not logged in to Azure. Run: az login"

gh auth status &>/dev/null  || error "Not logged in to GitHub CLI. Run: gh auth login"

# Verify gh has the required scopes (repo + admin:org minimum)
GH_SCOPES=$(gh auth status 2>&1 | grep -i "token scopes" || true)
info "GitHub token scopes: ${GH_SCOPES:-unknown (may be fine)}"

success "Azure CLI : $(az version --query '"azure-cli"' -o tsv)"
success "GitHub CLI: $(gh --version | head -1)"
success "Azure user: $(az account show --query 'user.name' -o tsv)"
success "GitHub user: $(gh api user --jq '.login')"

# Prompt for GITHUB_ORG if not set
if [[ -z "$GITHUB_ORG" ]]; then
  echo -n "Enter your GitHub organisation or username: "
  read -r GITHUB_ORG
  [[ -n "$GITHUB_ORG" ]] || error "GITHUB_ORG cannot be empty."
fi

# Prompt for SNYK_TOKEN if not set
if [[ -z "$SNYK_TOKEN" ]]; then
  echo -n "Enter your Snyk API token (leave blank to skip): "
  read -rs SNYK_TOKEN
  echo
fi

REPO_REF="${GITHUB_ORG}/${GITHUB_REPO}"

# Verify the repo is accessible
gh repo view "$REPO_REF" &>/dev/null \
  || error "Cannot access GitHub repo '${REPO_REF}'. Check GITHUB_ORG/GITHUB_REPO and gh auth scopes."

success "GitHub repo '${REPO_REF}' is accessible"

# ──────────────────────────────────────────────────────────────────────────────
# RESOLVE SUBSCRIPTION / TENANT
# ──────────────────────────────────────────────────────────────────────────────

header "Resolving Azure subscription"

ACCOUNT_JSON=$(az account show -o json)
SUBSCRIPTION_ID=$(echo "$ACCOUNT_JSON"   | jq -r '.id')
SUBSCRIPTION_NAME=$(echo "$ACCOUNT_JSON" | jq -r '.name')
TENANT_ID=$(echo "$ACCOUNT_JSON"         | jq -r '.tenantId')

info "Subscription : ${SUBSCRIPTION_NAME} (${SUBSCRIPTION_ID})"
info "Tenant       : ${TENANT_ID}"
info "Location     : ${LOCATION}"

SUBSCRIPTION_SCOPE="/subscriptions/${SUBSCRIPTION_ID}"

# Auto-generate storage account name from subscription ID if not provided
if [[ -z "$TF_STATE_SA" ]]; then
  SUFFIX=$(echo "$SUBSCRIPTION_ID" | tr -d '-' | cut -c1-16 | tr '[:upper:]' '[:lower:]')
  TF_STATE_SA="tfstate${SUFFIX}"
fi
info "TF state SA  : ${TF_STATE_SA}"

# ──────────────────────────────────────────────────────────────────────────────
# HELPER FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

assign_role() {
  local role="$1" scope="$2"
  local existing
  existing=$(az role assignment list \
    --assignee "$PRINCIPAL_ID" --role "$role" --scope "$scope" \
    --query "[0].id" -o tsv 2>/dev/null || true)
  if [[ -n "$existing" ]]; then
    warn "  Role '${role}' already assigned — skipped"
  else
    az role assignment create \
      --assignee-object-id "$PRINCIPAL_ID" \
      --assignee-principal-type ServicePrincipal \
      --role "$role" --scope "$scope" --output none
    success "  Assigned role '${role}'"
  fi
}

upsert_fed_credential() {
  local cred_name="$1" subject="$2"
  local existing
  existing=$(az identity federated-credential show \
    --identity-name "$IDENTITY_NAME" --resource-group "$BOOTSTRAP_RG" \
    --name "$cred_name" --query "id" -o tsv 2>/dev/null || true)
  if [[ -n "$existing" ]]; then
    warn "  Federated credential '${cred_name}' already exists — skipped"
  else
    az identity federated-credential create \
      --identity-name "$IDENTITY_NAME" --resource-group "$BOOTSTRAP_RG" \
      --name "$cred_name" \
      --issuer "https://token.actions.githubusercontent.com" \
      --subject "$subject" \
      --audiences "api://AzureADTokenExchange" \
      --output none
    success "  Created '${cred_name}'"
  fi
}

# gh secret set is always idempotent (overwrites existing value)
set_secret() {
  local name="$1" value="$2"
  echo -n "$value" | gh secret set "$name" --repo "$REPO_REF" --body -
  success "  Secret  : ${name}"
}

# gh variable set is always idempotent (overwrites existing value)
set_variable() {
  local name="$1" value="$2"
  gh variable set "$name" --repo "$REPO_REF" --body "$value"
  success "  Variable: ${name} = ${value}"
}

# Create GitHub environment (PUT is idempotent)
create_environment() {
  local env_name="$1"
  gh api \
    --method PUT \
    --silent \
    -H "Accept: application/vnd.github+json" \
    "/repos/${REPO_REF}/environments/${env_name}" > /dev/null
  success "  Environment '${env_name}' ready"
}

# ──────────────────────────────────────────────────────────────────────────────
# 1. BOOTSTRAP RESOURCE GROUP
# ──────────────────────────────────────────────────────────────────────────────

header "1 / Bootstrap resource group"

az group create --name "$BOOTSTRAP_RG" --location "$LOCATION" --output none
success "Resource group '${BOOTSTRAP_RG}' ready"

# ──────────────────────────────────────────────────────────────────────────────
# 2. TERRAFORM STATE STORAGE ACCOUNT
# ──────────────────────────────────────────────────────────────────────────────

header "2 / Terraform state storage"

az storage account create \
  --name "$TF_STATE_SA" \
  --resource-group "$BOOTSTRAP_RG" \
  --location "$LOCATION" \
  --sku "Standard_LRS" \
  --kind "StorageV2" \
  --min-tls-version "TLS1_2" \
  --allow-blob-public-access false \
  --https-only true \
  --output none
success "Storage account '${TF_STATE_SA}' ready"

az storage account blob-service-properties update \
  --account-name "$TF_STATE_SA" \
  --resource-group "$BOOTSTRAP_RG" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30 \
  --output none
success "Blob versioning + soft delete (30 days) enabled"

az storage container create \
  --name "$TF_STATE_CONTAINER" \
  --account-name "$TF_STATE_SA" \
  --auth-mode login \
  --output none
success "Container '${TF_STATE_CONTAINER}' ready"

# ──────────────────────────────────────────────────────────────────────────────
# 3. USER-ASSIGNED MANAGED IDENTITY
# ──────────────────────────────────────────────────────────────────────────────

header "3 / User-Assigned Managed Identity"

IDENTITY_JSON=$(az identity create \
  --name "$IDENTITY_NAME" \
  --resource-group "$BOOTSTRAP_RG" \
  --location "$LOCATION" \
  --output json)

CLIENT_ID=$(echo "$IDENTITY_JSON"    | jq -r '.clientId')
PRINCIPAL_ID=$(echo "$IDENTITY_JSON" | jq -r '.principalId')

success "Identity '${IDENTITY_NAME}' ready"
info    "  Client ID    : ${CLIENT_ID}"
info    "  Principal ID : ${PRINCIPAL_ID}"

# ──────────────────────────────────────────────────────────────────────────────
# 4. ROLE ASSIGNMENTS
# ──────────────────────────────────────────────────────────────────────────────

header "4 / Role assignments"

info "Waiting 20 s for AAD propagation before assigning roles..."
sleep 20

assign_role "Contributor"               "$SUBSCRIPTION_SCOPE"
assign_role "User Access Administrator" "$SUBSCRIPTION_SCOPE"

SA_SCOPE=$(az storage account show \
  --name "$TF_STATE_SA" --resource-group "$BOOTSTRAP_RG" --query "id" -o tsv)
assign_role "Storage Blob Data Contributor" "$SA_SCOPE"

# ──────────────────────────────────────────────────────────────────────────────
# 5. FEDERATED CREDENTIALS
# ──────────────────────────────────────────────────────────────────────────────

header "5 / Federated credentials (OIDC)"

upsert_fed_credential "github-push-main"       "repo:${REPO_REF}:ref:refs/heads/main"
upsert_fed_credential "github-pull-request"    "repo:${REPO_REF}:pull_request"
upsert_fed_credential "github-env-production"  "repo:${REPO_REF}:environment:production"
upsert_fed_credential "github-env-pr"          "repo:${REPO_REF}:environment:pull-request"

# ──────────────────────────────────────────────────────────────────────────────
# 6. GITHUB ACTIONS SECRETS
# ──────────────────────────────────────────────────────────────────────────────

header "6 / GitHub Actions secrets"

set_secret "AZURE_CLIENT_ID"       "$CLIENT_ID"
set_secret "AZURE_TENANT_ID"       "$TENANT_ID"
set_secret "AZURE_SUBSCRIPTION_ID" "$SUBSCRIPTION_ID"

if [[ -n "$SNYK_TOKEN" ]]; then
  set_secret "SNYK_TOKEN" "$SNYK_TOKEN"
else
  warn "  SNYK_TOKEN not provided — skipped (set it manually in GitHub Settings)"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 7. GITHUB ACTIONS VARIABLES
# ──────────────────────────────────────────────────────────────────────────────

header "7 / GitHub Actions variables"

# Terraform backend
set_variable "TF_BACKEND_RG"        "$BOOTSTRAP_RG"
set_variable "TF_BACKEND_SA"        "$TF_STATE_SA"
set_variable "TF_BACKEND_CONTAINER" "$TF_STATE_CONTAINER"

# Terraform input variables
set_variable "TF_VAR_LOCATION"      "$LOCATION"
set_variable "TF_VAR_RG_NAME"       "$TF_VAR_RG_NAME"
set_variable "TF_VAR_ENVIRONMENT"   "$TF_VAR_ENVIRONMENT"

# ──────────────────────────────────────────────────────────────────────────────
# 8. GITHUB ENVIRONMENTS
# ──────────────────────────────────────────────────────────────────────────────

header "8 / GitHub environments"

create_environment "production"
create_environment "pull-request"

warn "  Tip: add required reviewers to 'production' in GitHub Settings > Environments"

# ──────────────────────────────────────────────────────────────────────────────
# 9. SUMMARY
# ──────────────────────────────────────────────────────────────────────────────

header "Summary"

echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Azure resources${RESET}"
echo -e "${GREEN}══════════════════════════════════════════════════════${RESET}"
echo -e "  Resource group  : ${BOOTSTRAP_RG}"
echo -e "  State account   : ${TF_STATE_SA} / ${TF_STATE_CONTAINER}"
echo -e "  Managed identity: ${IDENTITY_NAME}"
echo -e "    Client ID     : ${CYAN}${CLIENT_ID}${RESET}"
echo -e "    Tenant ID     : ${CYAN}${TENANT_ID}${RESET}"
echo -e "    Subscription  : ${CYAN}${SUBSCRIPTION_ID}${RESET}"
echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  GitHub repo: ${REPO_REF}${RESET}"
echo -e "${GREEN}══════════════════════════════════════════════════════${RESET}"
echo -e "  Secrets set : AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID$([ -n "$SNYK_TOKEN" ] && echo ", SNYK_TOKEN")"
echo -e "  Variables set: TF_BACKEND_RG/SA/CONTAINER, TF_VAR_LOCATION/RG_NAME/ENVIRONMENT"
echo -e "  Variables set by Terraform: ACR_NAME, ACR_LOGIN_SERVER, AKS_CLUSTER_NAME, AKS_RESOURCE_GROUP,"
echo -e "    KEY_VAULT_NAME, KV_CSI_IDENTITY_CLIENT_ID, PSQL_FQDN, PSQL_ADMIN_USER, PSQL_DB_NAME, AZURE_TENANT_ID_VAR"
echo -e "  Environments : production, pull-request"
echo ""
echo -e "${YELLOW}Remaining manual steps:${RESET}"
echo "  1. Run Terraform to provision Azure resources and set GitHub variables:"
echo "     cd terraform"
echo "     terraform init -backend-config=\"resource_group_name=${BOOTSTRAP_RG}\" \\"
echo "                     -backend-config=\"storage_account_name=${TF_STATE_SA}\" \\"
echo "                     -backend-config=\"container_name=${TF_STATE_CONTAINER}\" \\"
echo "                     -backend-config=\"key=tfstate\""
echo "     terraform plan -var=\"github_owner=${GITHUB_ORG}\" -var=\"github_repository=${GITHUB_REPO}\""
echo "     terraform apply -var=\"github_owner=${GITHUB_ORG}\" -var=\"github_repository=${GITHUB_REPO}\""
echo ""
echo "  2. Add required reviewers to the 'production' environment:"
echo "     https://github.com/${REPO_REF}/settings/environments"
echo ""
echo "  3. Add SNYK_TOKEN if skipped above:"
echo "     gh secret set SNYK_TOKEN --repo ${REPO_REF}"
echo ""
echo "  4. Verify:"
echo "     gh secret list  --repo ${REPO_REF}"
echo "     gh variable list --repo ${REPO_REF}"
echo ""
