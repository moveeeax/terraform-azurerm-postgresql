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

  assert {
    condition     = azurerm_postgresql_flexible_server.this.delegated_subnet_id == null
    error_message = "The server must stay in public access mode by default: delegated_subnet_id is ForceNew, so a non-null default would recreate existing servers."
  }

  assert {
    condition     = length(azurerm_postgresql_flexible_server_firewall_rule.this) == 0
    error_message = "No firewall rules may be created by default."
  }

  assert {
    condition     = length(azurerm_postgresql_flexible_server.this.high_availability) == 0
    error_message = "High availability must stay off by default so existing servers plan unchanged."
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

run "private_access_with_delegated_subnet" {
  command = plan

  variables {
    delegated_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/postgres"
    private_dns_zone_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/test.postgres.database.azure.com"
  }

  assert {
    condition     = azurerm_postgresql_flexible_server.this.delegated_subnet_id == var.delegated_subnet_id
    error_message = "delegated_subnet_id must be wired through to the server."
  }

  assert {
    condition     = azurerm_postgresql_flexible_server.this.private_dns_zone_id == var.private_dns_zone_id
    error_message = "private_dns_zone_id must be wired through to the server."
  }

  assert {
    condition     = azurerm_postgresql_flexible_server.this.public_network_access_enabled == false
    error_message = "A VNet-integrated server must not be publicly reachable."
  }
}

run "firewall_rules_on_public_server" {
  command = plan

  variables {
    public_network_access_enabled = true
    firewall_rules = {
      office = {
        start_ip_address = "203.0.113.0"
        end_ip_address   = "203.0.113.255"
      }
      ci-runner = {
        start_ip_address = "198.51.100.7"
        end_ip_address   = "198.51.100.7"
      }
    }
  }

  assert {
    condition     = length(azurerm_postgresql_flexible_server_firewall_rule.this) == 2
    error_message = "One firewall rule must be created per firewall_rules entry."
  }

  assert {
    condition     = azurerm_postgresql_flexible_server_firewall_rule.this["office"].name == "office"
    error_message = "The firewall_rules key must be used as the rule name."
  }

  assert {
    condition = (
      azurerm_postgresql_flexible_server_firewall_rule.this["office"].start_ip_address == "203.0.113.0"
      && azurerm_postgresql_flexible_server_firewall_rule.this["office"].end_ip_address == "203.0.113.255"
    )
    error_message = "Firewall rule IP ranges must be wired through unchanged."
  }
}

run "zone_redundant_high_availability" {
  command = plan

  variables {
    sku_name = "GP_Standard_D2s_v3"
    zone     = "1"
    high_availability = {
      mode                      = "ZoneRedundant"
      standby_availability_zone = "2"
    }
  }

  assert {
    condition     = azurerm_postgresql_flexible_server.this.high_availability[0].mode == "ZoneRedundant"
    error_message = "high_availability.mode must be wired through to the server."
  }

  assert {
    condition     = azurerm_postgresql_flexible_server.this.high_availability[0].standby_availability_zone == "2"
    error_message = "high_availability.standby_availability_zone must be wired through to the server."
  }
}

run "same_zone_high_availability_without_standby_zone" {
  command = plan

  variables {
    sku_name = "MO_Standard_E4ds_v5"
    high_availability = {
      mode = "SameZone"
    }
  }

  assert {
    condition     = azurerm_postgresql_flexible_server.this.high_availability[0].mode == "SameZone"
    error_message = "SameZone must be accepted."
  }

  assert {
    condition     = azurerm_postgresql_flexible_server.this.high_availability[0].standby_availability_zone == null
    error_message = "An omitted standby_availability_zone must be left for Azure to choose."
  }
}
