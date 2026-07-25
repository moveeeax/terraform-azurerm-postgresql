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

  tags = var.tags
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
