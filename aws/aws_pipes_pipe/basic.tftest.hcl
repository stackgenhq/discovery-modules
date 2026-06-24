mock_provider "aws" {}

# Plan-only smoke test; no assert with literal true (OpenTofu rejects non-referential conditions).
run "basic_plan" {
  variables {
    name              = "test-pipe"
    source_arn        = "arn:aws:sqs:us-east-1:123456789012:test-queue"
    target_arn        = "arn:aws:sqs:us-east-1:123456789012:test-target"
    role_arn          = "arn:aws:iam::123456789012:role/test-role"
    kms_master_key_id = null
    tags              = {}
  }
  command = plan
}
