variable "name" {
  description = "Name of the PostgreSQL Flexible Server. Must be globally unique."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.name))
    error_message = "The name must be 3-63 characters of lowercase letters, numbers and hyphens, and may not start or end with a hyphen."
  }
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
  description = "Major version of PostgreSQL to run. Only versions that are still in community support are accepted."
  type        = string
  default     = "16"

  validation {
    condition     = contains(["14", "15", "16", "17"], var.postgresql_version)
    error_message = "postgresql_version must be one of 14, 15, 16 or 17. Versions 13 and below reached end of life and no longer receive security fixes."
  }
}

variable "sku_name" {
  description = "SKU of the server, e.g. B_Standard_B1ms or GP_Standard_D2s_v3."
  type        = string
  default     = "B_Standard_B1ms"

  validation {
    condition     = can(regex("^(B|GP|MO)_", var.sku_name))
    error_message = "sku_name must start with the tier prefix B_, GP_ or MO_, e.g. GP_Standard_D2s_v3."
  }
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

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 35 && floor(var.backup_retention_days) == var.backup_retention_days
    error_message = "backup_retention_days must be a whole number between 7 and 35."
  }
}

variable "geo_redundant_backup_enabled" {
  description = <<-EOT
    Whether backups are replicated to the paired Azure region. Deleting a
    Flexible Server also deletes its automated backups, so geo-redundancy is
    the only copy that survives the loss of the primary region. Azure only
    allows this to be set at creation time, so changing it on an existing
    server forces the server to be destroyed and recreated.
  EOT
  type        = bool
  default     = false
}

variable "zone" {
  description = "Availability zone in which the primary server is placed. Null lets Azure choose."
  type        = string
  default     = null
}

variable "administrator_login" {
  description = "Administrator login name for the server. Changing this destroys and recreates the server."
  type        = string
  default     = "psqladmin"

  validation {
    condition = (
      can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.administrator_login))
      && !contains(
        ["azure_superuser", "azure_pg_admin", "admin", "administrator", "root", "guest", "public"],
        lower(var.administrator_login)
      )
      && !startswith(lower(var.administrator_login), "pg_")
    )
    error_message = "administrator_login must start with a letter, contain only letters, digits and underscores, and must not be a name Azure reserves (azure_superuser, azure_pg_admin, admin, administrator, root, guest, public, or anything starting with pg_)."
  }
}

variable "administrator_password" {
  description = "Administrator password for the server. Has no default on purpose: pass it from a secret store, never a literal."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.administrator_password) >= 8 && length(var.administrator_password) <= 128
    error_message = "administrator_password must be between 8 and 128 characters, as required by Azure."
  }
}

variable "public_network_access_enabled" {
  description = "Whether the server is reachable over the public internet."
  type        = bool
  default     = false
}

variable "require_secure_transport" {
  description = "Whether the server rejects connections that are not TLS encrypted. Pins the require_secure_transport server parameter instead of inheriting the Azure default."
  type        = bool
  default     = true
}

variable "ssl_min_protocol_version" {
  description = "Minimum TLS version accepted by the server. Null leaves the ssl_min_protocol_version server parameter unmanaged, in which case Azure's own default (TLSv1.2) applies."
  type        = string
  default     = "TLSv1.2"

  validation {
    condition     = var.ssl_min_protocol_version == null || contains(["TLSv1.2", "TLSv1.3"], coalesce(var.ssl_min_protocol_version, "TLSv1.2"))
    error_message = "ssl_min_protocol_version must be TLSv1.2 or TLSv1.3. TLS 1.0 and 1.1 are deprecated and are not offered by this module."
  }
}

variable "tags" {
  description = "Map of tags applied to the server."
  type        = map(string)
  default     = {}
}
