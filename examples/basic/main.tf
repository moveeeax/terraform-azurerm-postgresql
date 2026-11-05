terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.105.0, < 6.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Supplied at apply time (TF_VAR_administrator_password, a -var-file kept out
# of version control, or a data source over your secret store). Deliberately
# has no default so the example cannot ship a working credential.
variable "administrator_password" {
  description = "Administrator password for the example server."
  type        = string
  sensitive   = true
}

module "postgresql" {
  source = "../.."

  name                = "example-pgflex"
  resource_group_name = "example-rg"
  location            = "eastus"

  postgresql_version     = "16"
  sku_name               = "B_Standard_B1ms"
  administrator_login    = "psqladmin"
  administrator_password = var.administrator_password

  tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }
}

output "postgresql_fqdn" {
  value = module.postgresql.fqdn
}
