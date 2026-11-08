resource "azurerm_postgresql_flexible_server" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  version                      = var.postgresql_version
  sku_name                     = var.sku_name
  storage_mb                   = var.storage_mb
  auto_grow_enabled            = var.auto_grow_enabled
  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled
  zone                         = var.zone

  administrator_login           = var.administrator_login
  administrator_password        = var.administrator_password
  public_network_access_enabled = var.public_network_access_enabled

  # Private access (VNet integration). Both default to null, which keeps the
  # server in public access mode. delegated_subnet_id is ForceNew: moving an
  # existing server into or out of a subnet destroys and recreates it.
  delegated_subnet_id = var.delegated_subnet_id
  private_dns_zone_id = var.private_dns_zone_id

  tags = var.tags

  # These checks span several variables, and cross-variable validation blocks
  # need Terraform 1.9. versions.tf still allows 1.5, so they live here.
  lifecycle {
    precondition {
      condition     = (var.delegated_subnet_id == null) == (var.private_dns_zone_id == null)
      error_message = "delegated_subnet_id and private_dns_zone_id must be set together: Azure requires a private DNS zone for a VNet-integrated server, and a private DNS zone has no effect without a delegated subnet."
    }

    precondition {
      condition     = var.delegated_subnet_id == null || !var.public_network_access_enabled
      error_message = "public_network_access_enabled must be false when delegated_subnet_id is set. A VNet-integrated server cannot also be reachable over the public internet."
    }

    precondition {
      condition     = length(var.firewall_rules) == 0 || var.public_network_access_enabled
      error_message = "firewall_rules only govern public access, so they require public_network_access_enabled = true (which in turn rules out delegated_subnet_id)."
    }
  }
}

# Allowed client IP ranges for a server in public access mode. Keyed by rule
# name so adding or removing one rule never touches the others.
resource "azurerm_postgresql_flexible_server_firewall_rule" "this" {
  for_each = var.firewall_rules

  name             = each.key
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = each.value.start_ip_address
  end_ip_address   = each.value.end_ip_address
}

# Encryption in transit. Azure currently defaults require_secure_transport to
# "on", but a server parameter default is not a guarantee: it can be flipped
# out of band and nothing in the config would notice. Pinning it here means
# Terraform detects and reverts the drift.
resource "azurerm_postgresql_flexible_server_configuration" "require_secure_transport" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = var.require_secure_transport ? "on" : "off"
}

resource "azurerm_postgresql_flexible_server_configuration" "ssl_min_protocol_version" {
  count = var.ssl_min_protocol_version == null ? 0 : 1

  name      = "ssl_min_protocol_version"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = var.ssl_min_protocol_version
}
