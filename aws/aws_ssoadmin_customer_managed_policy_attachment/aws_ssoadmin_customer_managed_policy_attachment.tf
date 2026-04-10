resource "aws_ssoadmin_customer_managed_policy_attachment" "this" {
  instance_arn       = var.instance_arn
  permission_set_arn = var.permission_set_arn

  dynamic "customer_managed_policy_reference" {
    for_each = var.customer_managed_policy_reference
    content {
      name = customer_managed_policy_reference.value.name
      path = customer_managed_policy_reference.value.path
    }
  }

  dynamic "timeouts" {
    for_each = var.timeouts != null ? [var.timeouts] : []
    content {
      create = lookup(timeouts.value, "create", null)
      delete = lookup(timeouts.value, "delete", null)
    }
  }

}
