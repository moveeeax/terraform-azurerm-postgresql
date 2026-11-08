# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Private access: `delegated_subnet_id` and `private_dns_zone_id` place the
  server in a delegated subnet with a private DNS zone. Both default to null,
  so existing servers stay in public access mode and their plan does not
  change. Plan-time checks require the two together, reject
  `public_network_access_enabled = true` with a delegated subnet, and check the
  ID formats (the zone name must end with `.postgres.database.azure.com`).
- Firewall rules: `firewall_rules` (map of rule name to IPv4
  `start_ip_address`/`end_ip_address`) creates
  `azurerm_postgresql_flexible_server_firewall_rule` resources. Defaults to `{}`.
  Rules require `public_network_access_enabled = true`; names, address format
  and range order are validated.
- Output `firewall_rule_ids`.

## [1.1.0] - 2026-11-05

See the [v1.1.0 release](https://github.com/moveeeax/terraform-azurerm-postgresql/releases/tag/v1.1.0).

## [1.0.0]

Initial release (`v0.1.0` points at the same commit).

[Unreleased]: https://github.com/moveeeax/terraform-azurerm-postgresql/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/moveeeax/terraform-azurerm-postgresql/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/moveeeax/terraform-azurerm-postgresql/releases/tag/v1.0.0
