resource "azurerm_postgresql_flexible_server" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  version                       = var.postgresql_version
  sku_name                      = var.sku_name
  storage_mb                    = var.storage_mb
  auto_grow_enabled             = var.auto_grow_enabled
  backup_retention_days         = var.backup_retention_days
  zone                          = var.zone
  administrator_login           = var.administrator_login
  administrator_password        = var.administrator_password
  public_network_access_enabled = var.public_network_access_enabled

  tags = var.tags
}
