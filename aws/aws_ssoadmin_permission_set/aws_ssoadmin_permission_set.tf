resource "aws_ssoadmin_permission_set" "this" {
  description      = var.description
  instance_arn     = var.instance_arn
  name             = var.name
  relay_state      = var.relay_state
  session_duration = var.session_duration
  tags             = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts != null ? [var.timeouts] : []
    content {
      update = lookup(timeouts.value, "update", null)
    }
  }

}
