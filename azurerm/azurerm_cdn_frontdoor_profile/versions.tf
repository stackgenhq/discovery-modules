terraform {
  required_version = ">= 1.0.0, < 2.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.9" // 3.9.0+ required for synapse workspace bugfix
    }

    azuread = { // Azure Active Directory
      source  = "hashicorp/azuread"
      version = "~> 3.1.0"
    }
  }
}