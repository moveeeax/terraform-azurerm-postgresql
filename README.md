# terraform-azurerm-postgresql

Terraform module that manages an [Azure](https://azure.microsoft.com/) Database
for PostgreSQL Flexible Server. It provisions a single server with configurable
version, compute SKU, storage and backup retention, keeps public network access
disabled by default, and exposes the connection FQDN.

## Usage

```hcl
module "postgresql" {
  source = "github.com/moveeeax/terraform-azurerm-postgresql"

  name                = "prod-pgflex"
  resource_group_name = "prod-rg"
  location            = "eastus"

  postgresql_version     = "16"
  sku_name               = "GP_Standard_D2s_v3"
  administrator_login    = "psqladmin"
  administrator_password = var.db_password

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| azurerm   | >= 3.0   |

## Inputs

| Name                            | Description                                                        | Type          | Default             | Required |
|---------------------------------|--------------------------------------------------------------------|---------------|---------------------|:--------:|
| `name`                          | Name of the PostgreSQL Flexible Server. Globally unique.           | `string`      | n/a                 |   yes    |
| `resource_group_name`           | Name of the resource group in which to create the server.          | `string`      | n/a                 |   yes    |
| `location`                      | Azure region in which to create the server.                        | `string`      | n/a                 |   yes    |
| `postgresql_version`            | Major version of PostgreSQL to run.                                | `string`      | `"16"`              |    no    |
| `sku_name`                      | SKU of the server.                                                 | `string`      | `"B_Standard_B1ms"` |    no    |
| `storage_mb`                    | Provisioned storage for the server in megabytes.                   | `number`      | `32768`             |    no    |
| `auto_grow_enabled`             | Whether storage auto-grow is enabled.                              | `bool`        | `true`              |    no    |
| `backup_retention_days`         | Days automated backups are retained, between 7 and 35.            | `number`      | `7`                 |    no    |
| `zone`                          | Availability zone for the primary server. Null lets Azure choose.  | `string`      | `null`              |    no    |
| `administrator_login`           | Administrator login name for the server.                           | `string`      | `"psqladmin"`       |    no    |
| `administrator_password`        | Administrator password for the server (sensitive).                 | `string`      | n/a                 |   yes    |
| `public_network_access_enabled` | Whether the server is reachable over the public internet.          | `bool`        | `false`             |    no    |
| `tags`                          | Map of tags applied to the server.                                 | `map(string)` | `{}`                |    no    |

## Outputs

| Name   | Description                                        |
|--------|----------------------------------------------------|
| `id`   | ID of the PostgreSQL Flexible Server.              |
| `name` | Name of the PostgreSQL Flexible Server.            |
| `fqdn` | Fully qualified domain name to connect to the server.|

## License

[MIT](LICENSE)
