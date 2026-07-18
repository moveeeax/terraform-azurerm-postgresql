terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "postgresql" {
  source = "../.."

  name                = "example-pgflex"
  resource_group_name = "example-rg"
  location            = "eastus"

  postgresql_version     = "16"
  sku_name               = "B_Standard_B1ms"
  administrator_login    = "psqladmin"
  administrator_password = "ChangeMe-Example-P4ss!"

  tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }
}

output "postgresql_fqdn" {
  value = module.postgresql.fqdn
}
