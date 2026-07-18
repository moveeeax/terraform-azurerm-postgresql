variable "name" {
  description = "Name of the PostgreSQL Flexible Server. Must be globally unique."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group in which to create the server."
  type        = string
}

variable "location" {
  description = "Azure region in which to create the server."
  type        = string
}

variable "postgresql_version" {
  description = "Major version of PostgreSQL to run, e.g. 14, 15 or 16."
  type        = string
  default     = "16"
}

variable "sku_name" {
  description = "SKU of the server, e.g. B_Standard_B1ms or GP_Standard_D2s_v3."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Provisioned storage for the server in megabytes."
  type        = number
  default     = 32768
}

variable "auto_grow_enabled" {
  description = "Whether storage auto-grow is enabled on the server."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days automated backups are retained, between 7 and 35."
  type        = number
  default     = 7
}

variable "zone" {
  description = "Availability zone in which the primary server is placed. Null lets Azure choose."
  type        = string
  default     = null
}

variable "administrator_login" {
  description = "Administrator login name for the server."
  type        = string
  default     = "psqladmin"
}

variable "administrator_password" {
  description = "Administrator password for the server."
  type        = string
  sensitive   = true
}

variable "public_network_access_enabled" {
  description = "Whether the server is reachable over the public internet."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Map of tags applied to the server."
  type        = map(string)
  default     = {}
}
