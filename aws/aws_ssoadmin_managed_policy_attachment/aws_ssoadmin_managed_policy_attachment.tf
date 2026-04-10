resource "aws_ssoadmin_managed_policy_attachment" "this" {
  instance_arn       = var.instance_arn
  managed_policy_arn = var.managed_policy_arn
  permission_set_arn = var.permission_set_arn

  dynamic "timeouts" {
    for_each = var.timeouts != null ? [var.timeouts] : []
    content {
      create = lookup(timeouts.value, "create", null)
      delete = lookup(timeouts.value, "delete", null)
    }
  }

}
