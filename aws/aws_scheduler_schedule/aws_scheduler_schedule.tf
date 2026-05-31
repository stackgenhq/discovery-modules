resource "aws_scheduler_schedule" "this" {
  name                = var.name
  description         = var.description
  schedule_expression = var.schedule_expression
  flexible_time_window {
    mode = var.flexible_time_window_mode
  }

  group_name                   = var.group_name
  start_date                   = var.start_date
  end_date                     = var.end_date
  schedule_expression_timezone = var.schedule_expression_timezone
  kms_key_arn                  = var.kms_key_arn
  state                        = var.state

  target {
    arn      = var.target_arn
    role_arn = var.target_role_arn
    input    = var.target_input
  }
}
