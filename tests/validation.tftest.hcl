# Requires Terraform >= 1.7 / OpenTofu >= 1.7 for mock_provider.

mock_provider "azurerm" {
  # ssl_min_protocol_version drives a `count`, so OpenTofu expands and plans the
  # configuration resource even on runs that are only meant to trip a variable
  # validation. The provider parses server_id as a real Azure resource ID, so the
  # mocked server needs a well-formed (but entirely fictional) one.
  mock_resource "azurerm_postgresql_flexible_server" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-pgflex"
    }
  }
}

variables {
  name                   = "test-pgflex"
  resource_group_name    = "test-rg"
  location               = "eastus"
  administrator_password = "not-a-real-password"
}

run "rejects_end_of_life_postgresql_version" {
  command = plan

  variables {
    postgresql_version = "11"
  }

  expect_failures = [var.postgresql_version]
}

run "rejects_backup_retention_below_azure_minimum" {
  command = plan

  variables {
    backup_retention_days = 1
  }

  expect_failures = [var.backup_retention_days]
}

run "rejects_backup_retention_above_azure_maximum" {
  command = plan

  variables {
    backup_retention_days = 90
  }

  expect_failures = [var.backup_retention_days]
}

run "rejects_reserved_administrator_login" {
  command = plan

  variables {
    administrator_login = "azure_superuser"
  }

  expect_failures = [var.administrator_login]
}

run "rejects_short_administrator_password" {
  command = plan

  variables {
    administrator_password = "short"
  }

  expect_failures = [var.administrator_password]
}

run "rejects_deprecated_tls_version" {
  command = plan

  variables {
    ssl_min_protocol_version = "TLSv1.0"
  }

  expect_failures = [var.ssl_min_protocol_version]
}

run "rejects_invalid_server_name" {
  command = plan

  variables {
    name = "Invalid_Server_Name"
  }

  expect_failures = [var.name]
}
