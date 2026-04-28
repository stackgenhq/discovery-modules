resource "azurerm_cdn_frontdoor_profile" "this" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  response_timeout_seconds = var.response_timeout_seconds
  sku_name                 = var.sku_name
  tags                     = var.tags

  dynamic "identity" {
    for_each = var.identity
    content {
      identity_ids = identity.value.identity_ids
      type         = identity.value.type
    }
  }

  dynamic "log_scrubbing_rule" {
    for_each = var.log_scrubbing_rule
    content {
      match_variable = log_scrubbing_rule.value.match_variable
    }
  }

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
