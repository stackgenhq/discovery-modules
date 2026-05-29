variables {
  name                               = "test-blue-green"
  cluster                            = "arn:aws:ecs:us-east-1:123456789012:cluster/test"
  task_definition                    = null
  desired_count                      = 1
  launch_type                        = "FARGATE"
  platform_version                   = null
  scheduling_strategy                = null
  deployment_maximum_percent         = null
  deployment_minimum_healthy_percent = null
  enable_ecs_managed_tags            = null
  enable_execute_command             = null
  health_check_grace_period_seconds  = null
  propagate_tags                     = null
  wait_for_steady_state              = null
  tags                               = null
  load_balancer                      = []
  network_configuration              = []
  capacity_provider_strategy         = []
  service_registries                 = []
  timeouts = {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

run "ecs_service_blue_green" {
  command = plan
  assert {
    condition     = aws_ecs_service.this.name == "test-blue-green"
    error_message = "Expected the ECS service name to be test-blue-green"
  }
}
