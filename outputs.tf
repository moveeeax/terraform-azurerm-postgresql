output "id" {
  description = "ID of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.this.id
}

output "name" {
  description = "Name of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.this.name
}

output "fqdn" {
  description = "Fully qualified domain name used to connect to the server."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "firewall_rule_ids" {
  description = "Map of firewall rule name to rule ID. Empty when no firewall_rules are set."
  value       = { for name, rule in azurerm_postgresql_flexible_server_firewall_rule.this : name => rule.id }
}
