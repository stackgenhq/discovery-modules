provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
}

run "plan_blue_green_service" {
  command = plan

  variables {
    cluster_arn           = "arn:aws:ecs:us-east-1:123456789012:cluster/test-cluster"
    service_name          = "test-bg-service"
    task_definition_arn   = "arn:aws:ecs:us-east-1:123456789012:task-definition/test:1"
    desired_count         = 2
    target_group_blue_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/blue/abc123"
    container_name        = "app"
    container_port        = 8080
    subnet_ids            = ["subnet-12345678", "subnet-87654321"]
    security_group_ids    = ["sg-12345678"]
    tags = {
      Environment = "test"
      ManagedBy   = "terraform"
    }
  }

  assert {
    condition     = aws_ecs_service.this.name == "test-bg-service"
    error_message = "ECS service name must match input"
  }

  assert {
    condition     = aws_ecs_service.this.desired_count == 2
    error_message = "Desired count must match input"
  }
}
