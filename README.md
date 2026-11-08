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
| Network mode                  | public access (no delegated subnet), no firewall rules |
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

## Network access

The server runs in one of two network modes, chosen at creation time.

Public access (the default). `delegated_subnet_id` stays null and the server
gets a public endpoint, which is closed while `public_network_access_enabled`
is `false`. To let clients in, set it to `true` and list the allowed IPv4
ranges in `firewall_rules`; with no rules, Azure accepts no client IPs.

```hcl
  public_network_access_enabled = true
  firewall_rules = {
    office    = { start_ip_address = "203.0.113.0", end_ip_address = "203.0.113.255" }
    ci-runner = { start_ip_address = "198.51.100.7", end_ip_address = "198.51.100.7" }
  }
```

The range `0.0.0.0`-`0.0.0.0` is Azure's "allow Azure services" switch. It
admits any Azure resource, including ones in other customers' subscriptions,
so prefer explicit ranges.

Private access (VNet integration, recommended for production). Pass a subnet
dedicated to the server and a private DNS zone whose name ends with
`.postgres.database.azure.com`; `public_network_access_enabled` must stay
`false` and `firewall_rules` empty.

```hcl
  delegated_subnet_id = azurerm_subnet.postgres.id
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id
```

Link the zone to the VNet (`azurerm_private_dns_zone_virtual_network_link`)
and make the module depend on that link; the azurerm documentation example
does the same. `delegated_subnet_id` is ForceNew: switching an
existing server between public and private access destroys and recreates it,
data included. Plan the mode before the first apply.

The module enforces the combinations at plan time: `delegated_subnet_id` and
`private_dns_zone_id` go together, a delegated subnet rules out public access,
and firewall rules require public access.

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
| `delegated_subnet_id`           | Subnet for private access (VNet integration). Null keeps public access. ForceNew. | `string` | `null`          |    no    |
| `private_dns_zone_id`           | Private DNS zone (`*.postgres.database.azure.com`). Required with `delegated_subnet_id`. | `string` | `null`   |    no    |
| `firewall_rules`                | Allowed IPv4 ranges, keyed by rule name. Requires public access.           | `map(object({ start_ip_address = string, end_ip_address = string }))` | `{}` | no |
| `require_secure_transport`      | Reject connections that are not TLS encrypted.                              | `bool`        | `true`              |    no    |
| `ssl_min_protocol_version`      | Minimum TLS version (`TLSv1.2`, `TLSv1.3`, or `null` to leave unmanaged).   | `string`      | `"TLSv1.2"`         |    no    |
| `tags`                          | Map of tags applied to the server.                                          | `map(string)` | `{}`                |    no    |

## Outputs

| Name   | Description                                        |
|--------|----------------------------------------------------|
| `id`   | ID of the PostgreSQL Flexible Server.              |
| `name` | Name of the PostgreSQL Flexible Server.            |
| `fqdn` | Fully qualified domain name to connect to the server.|
| `firewall_rule_ids` | Map of firewall rule name to rule ID.          |

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
