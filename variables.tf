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

variable "delegated_subnet_id" {
  description = <<-EOT
    ID of a subnet to place the server in (private access / VNet integration).
    The subnet is delegated to Microsoft.DBforPostgreSQL/flexibleServers and must
    not host anything else. Requires private_dns_zone_id and
    public_network_access_enabled = false. Null keeps the server in public
    access mode. Changing this on an existing server forces it to be destroyed
    and recreated.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.delegated_subnet_id == null ? true : can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.delegated_subnet_id))
    error_message = "delegated_subnet_id must be a subnet resource ID: /subscriptions/<id>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<subnet>."
  }
}

variable "private_dns_zone_id" {
  description = "ID of the private DNS zone that resolves the server name inside the VNet. Required with delegated_subnet_id, which it must accompany. The zone name must end with .postgres.database.azure.com."
  type        = string
  default     = null

  validation {
    condition     = var.private_dns_zone_id == null ? true : can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/privateDnsZones/[^/]+\\.postgres\\.database\\.azure\\.com$", var.private_dns_zone_id))
    error_message = "private_dns_zone_id must be a private DNS zone resource ID whose zone name ends with .postgres.database.azure.com."
  }
}

variable "firewall_rules" {
  description = <<-EOT
    Firewall rules for a server in public access mode, keyed by rule name. Each
    rule allows the inclusive IPv4 range start_ip_address..end_ip_address. Only
    valid with public_network_access_enabled = true. The special range
    0.0.0.0-0.0.0.0 allows connections from any Azure service, including
    resources in other customers' subscriptions, so prefer explicit ranges.
  EOT
  type = map(object({
    start_ip_address = string
    end_ip_address   = string
  }))
  default = {}

  validation {
    condition     = alltrue([for name in keys(var.firewall_rules) : can(regex("^[a-zA-Z0-9_-]{1,128}$", name))])
    error_message = "firewall_rules keys are used as rule names and must be 1-128 letters, digits, hyphens or underscores."
  }

  validation {
    condition = alltrue(flatten([
      for rule in values(var.firewall_rules) : [
        for ip in [rule.start_ip_address, rule.end_ip_address] :
        can(regex("^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$", ip))
      ]
    ]))
    error_message = "Every firewall_rules start_ip_address and end_ip_address must be a dotted IPv4 address, e.g. 203.0.113.10."
  }

  validation {
    # try(): a malformed address is reported by the block above, not here.
    condition = alltrue([
      for rule in values(var.firewall_rules) : try(
        sum([for i, octet in split(".", rule.start_ip_address) : tonumber(octet) * pow(256, 3 - i)])
        <= sum([for i, octet in split(".", rule.end_ip_address) : tonumber(octet) * pow(256, 3 - i)]),
        true
      )
    ])
    error_message = "Every firewall_rules start_ip_address must be less than or equal to its end_ip_address."
  }
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
    condition     = var.ssl_min_protocol_version == null ? true : contains(["TLSv1.2", "TLSv1.3"], var.ssl_min_protocol_version)
    error_message = "ssl_min_protocol_version must be TLSv1.2 or TLSv1.3. TLS 1.0 and 1.1 are deprecated and are not offered by this module."
  }
}

variable "tags" {
  description = "Map of tags applied to the server."
  type        = map(string)
  default     = {}
}
