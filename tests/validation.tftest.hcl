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

run "rejects_malformed_delegated_subnet_id" {
  command = plan

  variables {
    delegated_subnet_id = "test-vnet/postgres"
    private_dns_zone_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/test.postgres.database.azure.com"
  }

  expect_failures = [var.delegated_subnet_id]
}

run "rejects_private_dns_zone_with_wrong_suffix" {
  command = plan

  variables {
    delegated_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/postgres"
    private_dns_zone_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/example.internal"
  }

  expect_failures = [var.private_dns_zone_id]
}

run "rejects_delegated_subnet_without_private_dns_zone" {
  command = plan

  variables {
    delegated_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/postgres"
  }

  expect_failures = [azurerm_postgresql_flexible_server.this]
}

run "rejects_private_dns_zone_without_delegated_subnet" {
  command = plan

  variables {
    private_dns_zone_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/test.postgres.database.azure.com"
  }

  expect_failures = [azurerm_postgresql_flexible_server.this]
}

run "rejects_public_access_with_delegated_subnet" {
  command = plan

  variables {
    delegated_subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/postgres"
    private_dns_zone_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/test.postgres.database.azure.com"
    public_network_access_enabled = true
  }

  expect_failures = [azurerm_postgresql_flexible_server.this]
}

run "rejects_firewall_rules_without_public_access" {
  command = plan

  variables {
    firewall_rules = {
      office = {
        start_ip_address = "203.0.113.0"
        end_ip_address   = "203.0.113.255"
      }
    }
  }

  expect_failures = [azurerm_postgresql_flexible_server.this]
}

run "rejects_invalid_firewall_rule_ip" {
  command = plan

  variables {
    public_network_access_enabled = true
    firewall_rules = {
      office = {
        start_ip_address = "203.0.113.300"
        end_ip_address   = "203.0.113.255"
      }
    }
  }

  expect_failures = [var.firewall_rules]
}

run "rejects_ipv6_firewall_rule" {
  command = plan

  variables {
    public_network_access_enabled = true
    firewall_rules = {
      office = {
        start_ip_address = "2001:db8::1"
        end_ip_address   = "2001:db8::ff"
      }
    }
  }

  expect_failures = [var.firewall_rules]
}

run "rejects_reversed_firewall_rule_range" {
  command = plan

  variables {
    public_network_access_enabled = true
    firewall_rules = {
      office = {
        start_ip_address = "203.0.113.255"
        end_ip_address   = "203.0.113.0"
      }
    }
  }

  expect_failures = [var.firewall_rules]
}

run "rejects_invalid_firewall_rule_name" {
  command = plan

  variables {
    public_network_access_enabled = true
    firewall_rules = {
      "office wifi" = {
        start_ip_address = "203.0.113.0"
        end_ip_address   = "203.0.113.255"
      }
    }
  }

  expect_failures = [var.firewall_rules]
}

run "rejects_unknown_high_availability_mode" {
  command = plan

  variables {
    sku_name = "GP_Standard_D2s_v3"
    high_availability = {
      mode = "Disabled"
    }
  }

  expect_failures = [var.high_availability]
}

run "rejects_high_availability_on_burstable_sku" {
  command = plan

  variables {
    sku_name = "B_Standard_B1ms"
    high_availability = {
      mode = "ZoneRedundant"
    }
  }

  expect_failures = [azurerm_postgresql_flexible_server.this]
}
