terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # 3.105.0 is the oldest provider this module actually works against:
      #   - auto_grow_enabled does not exist on the resource up to 3.70.0
      #     ("An argument named auto_grow_enabled is not expected here")
      #   - public_network_access_enabled is a read-only computed attribute up
      #     to 3.104.0 ("Value for unconfigurable attribute")
      # Both were verified with `terraform validate` against pinned providers.
      # Ceiling: validated and tested on 5.x; 6.0 has not been vetted.
      version = ">= 3.105.0, < 6.0"
    }
  }
}
