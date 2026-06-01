mock_provider "aws" {}

# Plan-only smoke test; no assert with literal true (OpenTofu rejects non-referential conditions).
run "basic_plan" {
  command = plan
}
