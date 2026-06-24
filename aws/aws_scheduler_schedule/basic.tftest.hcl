mock_provider "aws" {}

variables {
  name                = "test-schedule"
  schedule_expression = "rate(5 minutes)"
  target_arn          = "arn:aws:sqs:us-east-1:123456789012:test-queue"
  target_role_arn     = "arn:aws:iam::123456789012:role/test-role"
}

run "basic_plan" {
  command = plan

  assert {
    condition     = aws_scheduler_schedule.this.name == "test-schedule"
    error_message = "schedule name should match input variable"
  }
}

run "schedule_expression_check" {
  command = plan

  assert {
    condition     = aws_scheduler_schedule.this.schedule_expression == "rate(5 minutes)"
    error_message = "schedule expression should match input variable"
  }
}
