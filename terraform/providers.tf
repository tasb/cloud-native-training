terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.63"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  # Partial backend config — all values are injected at runtime via -backend-config flags.
  # See .github/workflows/terraform.yml for usage.
  backend "azurerm" {}
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "github" {
  owner = var.github_owner
  # Uses GITHUB_TOKEN environment variable for authentication
  # Set this in your CI/CD pipeline or local environment
}

data "azurerm_client_config" "current" {}
