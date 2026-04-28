resource "azurerm_app_service_certificate" "this" {
  app_service_plan_id = var.app_service_plan_id
  key_vault_id        = var.key_vault_id
  key_vault_secret_id = var.key_vault_secret_id
  location            = var.location
  name                = var.name
  password            = var.password
  pfx_blob            = var.pfx_blob
  resource_group_name = var.resource_group_name
  tags                = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts != null ? [var.timeouts] : []
    content {
      create = lookup(timeouts.value, "create", null)
      delete = lookup(timeouts.value, "delete", null)
      read   = lookup(timeouts.value, "read", null)
      update = lookup(timeouts.value, "update", null)
    }
  }

}
