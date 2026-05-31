mock_provider "aws" {}

variables {
  name             = "test-service"
  cluster          = "arn:aws:ecs:us-east-1:123456789012:cluster/test-cluster"
  task_definition  = "arn:aws:ecs:us-east-1:123456789012:task-definition/test-task:1"
  subnets          = ["subnet-12345"]
  security_groups  = ["sg-12345"]
  target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test-tg/12345"
  container_name   = "web"
  container_port   = 80
}

run "plan" {
  command = plan
  assert {
    condition     = aws_ecs_service.this.deployment_controller[0].type == "CODE_DEPLOY"
    error_message = "Deployment controller must be CODE_DEPLOY"
  }
}
