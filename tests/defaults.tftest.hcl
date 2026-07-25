# Requires Terraform >= 1.7 / OpenTofu >= 1.7 for mock_provider. This is a
# test-only requirement: the module itself still supports >= 1.5, so
# required_version in versions.tf is deliberately left alone.

mock_provider "azurerm" {
  # The provider parses server_id as a real Azure resource ID, so the mocked
  # server needs a well-formed (but entirely fictional) one.
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

run "defaults_are_safe" {
  assert {
    condition     = azurerm_postgresql_flexible_server.this.public_network_access_enabled == false
    error_message = "The server must not be exposed to the public internet by default."
  }

  assert {
    condition     = azurerm_postgresql_flexible_server_configuration.require_secure_transport.value == "on"
    error_message = "TLS must be required for client connections by default."
  }

  assert {
    condition     = one(azurerm_postgresql_flexible_server_configuration.ssl_min_protocol_version[*].value) == "TLSv1.2"
    error_message = "The minimum TLS version must default to TLSv1.2."
  }

  assert {
    condition     = azurerm_postgresql_flexible_server.this.backup_retention_days >= 7
    error_message = "Automated backups must be retained for at least 7 days."
  }

  assert {
    condition     = azurerm_postgresql_flexible_server.this.auto_grow_enabled == true
    error_message = "Storage auto-grow must be on by default so a full disk does not take the server read-only."
  }

  assert {
    condition     = azurerm_postgresql_flexible_server.this.version == "16"
    error_message = "The default PostgreSQL major version must be one that is still in community support."
  }
}

run "opting_into_public_access_is_explicit" {
  variables {
    public_network_access_enabled = true
  }

  assert {
    condition     = azurerm_postgresql_flexible_server.this.public_network_access_enabled == true
    error_message = "public_network_access_enabled must be honoured when a caller opts in."
  }
}

run "geo_redundant_backup_can_be_enabled" {
  variables {
    geo_redundant_backup_enabled = true
  }

  assert {
    condition     = azurerm_postgresql_flexible_server.this.geo_redundant_backup_enabled == true
    error_message = "geo_redundant_backup_enabled must be wired through to the server."
  }
}

run "ssl_parameter_can_be_left_unmanaged" {
  variables {
    ssl_min_protocol_version = null
  }

  assert {
    condition     = length(azurerm_postgresql_flexible_server_configuration.ssl_min_protocol_version) == 0
    error_message = "A null ssl_min_protocol_version must not create a configuration resource."
  }
}
