variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "rg-cloud-native-training"
}

variable "environment" {
  description = "Environment label used in resource naming (max 8 chars)"
  type        = string
  default     = "training"

  validation {
    condition     = length(var.environment) <= 8
    error_message = "Environment name must be 8 characters or fewer to keep resource names within limits."
  }
}

# ─── AKS ──────────────────────────────────────────────────────────────────────

variable "aks_kubernetes_version" {
  description = "Kubernetes version for AKS (check: az aks get-versions --location westeurope)"
  type        = string
  default     = "1.31"
}

variable "aks_system_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 2
}

variable "aks_vm_size" {
  description = "VM size for the system node pool (regular VMs)"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "aks_spot_vm_size" {
  description = "VM size for the spot user node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "aks_spot_min_count" {
  description = "Minimum node count for the spot user pool (0 = scale to zero when idle)"
  type        = number
  default     = 0
}

variable "aks_spot_max_count" {
  description = "Maximum node count for the spot user pool"
  type        = number
  default     = 5
}

# ─── ACR ──────────────────────────────────────────────────────────────────────

variable "acr_sku" {
  description = "Azure Container Registry SKU: Basic, Standard, or Premium"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "ACR SKU must be Basic, Standard, or Premium."
  }
}

# ─── PostgreSQL ───────────────────────────────────────────────────────────────

variable "postgresql_admin_username" {
  description = "PostgreSQL Flexible Server administrator login"
  type        = string
  default     = "pgadmin"
}

variable "postgresql_sku" {
  description = "PostgreSQL Flexible Server SKU name"
  type        = string
  default     = "B_Standard_B2s"
}

variable "postgresql_storage_mb" {
  description = "PostgreSQL storage in MB (32768 = 32 GB)"
  type        = number
  default     = 32768
}

variable "postgresql_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "15"
}

# ─── GitHub ───────────────────────────────────────────────────────────────────

variable "github_owner" {
  description = "GitHub organization or username that owns the repository"
  type        = string
  default     = "tasb"
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
  default     = "cloud-native-training"
}

# ─── Tags ─────────────────────────────────────────────────────────────────────

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Project   = "cloud-native-training"
    ManagedBy = "terraform"
  }
}
