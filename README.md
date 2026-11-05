# terraform-azurerm-postgresql

Terraform module that manages an [Azure](https://azure.microsoft.com/) Database
for PostgreSQL Flexible Server. It provisions a single server with configurable
version, compute SKU, storage and backup retention, keeps public network access
disabled and TLS required by default, and exposes the connection FQDN.

## Usage

```hcl
module "postgresql" {
  source = "github.com/moveeeax/terraform-azurerm-postgresql?ref=v1.0.0"

  name                = "prod-pgflex"
  resource_group_name = "prod-rg"
  location            = "eastus"

  postgresql_version = "16"
  sku_name           = "GP_Standard_D2s_v3"

  administrator_login    = "psqladmin"
  administrator_password = var.db_password # from a secret store, never a literal

  # Recommended for anything you cannot afford to lose. Deleting a Flexible
  # Server deletes its automated backups with it; geo-redundant backup is the
  # only copy that outlives the primary region. Creation-time only.
  geo_redundant_backup_enabled = true
  backup_retention_days        = 35

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

`administrator_password` has no default on purpose. Supply it from a secret
store (Key Vault, SOPS, your CI's secret mechanism) or `TF_VAR_administrator_password`;
it will be written to state, so treat the state backend as a secret store too.

## Requirements

| Name      | Version              |
|-----------|----------------------|
| terraform | >= 1.5               |
| azurerm   | >= 3.105.0, < 6.0    |

The azurerm floor is not decorative: `public_network_access_enabled` is a
read-only computed attribute on `azurerm_postgresql_flexible_server` up to
azurerm 3.104.0, and `auto_grow_enabled` does not exist at all in older 3.x.
Anything below 3.105.0 fails at plan time. CI validates against the floor and
runs the test suite against the latest 5.x release; 6.x is excluded until it
has been tested.

Running the test suite (`terraform test` / `tofu test`) additionally needs
Terraform or OpenTofu >= 1.7 for `mock_provider`. That is a test-only
requirement; the module itself still supports 1.5.

## Security defaults

| Behaviour                     | Default                                              |
|-------------------------------|------------------------------------------------------|
| Public network access         | disabled                                             |
| TLS required for connections  | yes (`require_secure_transport = on`, pinned)        |
| Minimum TLS version           | `TLSv1.2` (pinned; `TLSv1.3` also accepted)          |
| Storage auto-grow             | enabled                                              |
| Backup retention              | 7 days (Azure minimum — raise it for production)     |
| Geo-redundant backup          | disabled (Azure default; opt in, creation-time only) |
| PostgreSQL major version      | `16`; only 14-17 accepted                            |

`require_secure_transport` and `ssl_min_protocol_version` are managed as
explicit `azurerm_postgresql_flexible_server_configuration` resources rather
than left to inherit Azure's own parameter defaults, so out-of-band changes
show up as drift.

## Inputs

| Name                            | Description                                                                 | Type          | Default             | Required |
|---------------------------------|-----------------------------------------------------------------------------|---------------|---------------------|:--------:|
| `name`                          | Name of the PostgreSQL Flexible Server. Globally unique.                    | `string`      | n/a                 |   yes    |
| `resource_group_name`           | Name of the resource group in which to create the server.                   | `string`      | n/a                 |   yes    |
| `location`                      | Azure region in which to create the server.                                 | `string`      | n/a                 |   yes    |
| `administrator_password`        | Administrator password for the server (sensitive, 8-128 chars).             | `string`      | n/a                 |   yes    |
| `postgresql_version`            | Major version of PostgreSQL to run. One of `14`, `15`, `16`, `17`.          | `string`      | `"16"`              |    no    |
| `sku_name`                      | SKU of the server. Must start with `B_`, `GP_` or `MO_`.                    | `string`      | `"B_Standard_B1ms"` |    no    |
| `storage_mb`                    | Provisioned storage for the server in megabytes.                            | `number`      | `32768`             |    no    |
| `auto_grow_enabled`             | Whether storage auto-grow is enabled.                                       | `bool`        | `true`              |    no    |
| `backup_retention_days`         | Days automated backups are retained, between 7 and 35.                      | `number`      | `7`                 |    no    |
| `geo_redundant_backup_enabled`  | Replicate backups to the paired region. Creation-time only.                 | `bool`        | `false`             |    no    |
| `zone`                          | Availability zone for the primary server. Null lets Azure choose.           | `string`      | `null`              |    no    |
| `administrator_login`           | Administrator login name. Reserved Azure names are rejected.                | `string`      | `"psqladmin"`       |    no    |
| `public_network_access_enabled` | Whether the server is reachable over the public internet.                   | `bool`        | `false`             |    no    |
| `require_secure_transport`      | Reject connections that are not TLS encrypted.                              | `bool`        | `true`              |    no    |
| `ssl_min_protocol_version`      | Minimum TLS version (`TLSv1.2`, `TLSv1.3`, or `null` to leave unmanaged).   | `string`      | `"TLSv1.2"`         |    no    |
| `tags`                          | Map of tags applied to the server.                                          | `map(string)` | `{}`                |    no    |

## Outputs

| Name   | Description                                        |
|--------|----------------------------------------------------|
| `id`   | ID of the PostgreSQL Flexible Server.              |
| `name` | Name of the PostgreSQL Flexible Server.            |
| `fqdn` | Fully qualified domain name to connect to the server.|

## Tests

```sh
terraform init -backend=false
terraform test
```

The suite runs entirely against a mocked provider — no Azure credentials, no
network, no cost. It pins the safe defaults above and asserts that every input
validation rejects what it claims to reject.

## License

[MIT](LICENSE)
