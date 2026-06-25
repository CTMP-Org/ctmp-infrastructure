

output "server_fqdn" {
  description = "Fully Qualified Domain Name of the PostgreSQL server."
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "server_name" {
  description = "Name of the PostgreSQL server."
  value       = azurerm_postgresql_flexible_server.main.name
}

output "database_name" {
  description = "Name of the created database."
  value       = azurerm_postgresql_flexible_server_database.main.name
}

output "server_id" {
  description = "Resource ID of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.main.id
}

