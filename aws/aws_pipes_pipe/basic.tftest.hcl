mock_provider "aws" {}

run "basic_plan" {
  command = plan

  assert {
    condition     = true
    error_message = "plan should succeed with mock provider"
  }
}
