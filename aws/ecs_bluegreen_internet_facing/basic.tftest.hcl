variables {
  name                              = "test-bg-svc"
  aws_region                        = "us-east-1"
  vpc_id                            = "vpc-0a1eeecd978b2d990"
  public_subnet_ids                 = ["subnet-0a1eeecd978b2d990", "subnet-06a1939485b03e1e8"]
  private_subnet_ids                = ["subnet-0227e2b0abc5f975e", "subnet-0337e3c0bcd6g086f"]
  ecs_cluster_arn                   = "arn:aws:ecs:us-east-1:123456789012:cluster/my-cluster"
  ecs_cluster_name                  = "my-cluster"
  certificate_arn                   = "arn:aws:acm:us-east-1:123456789012:certificate/abc12345-1234-1234-1234-abc123456789"
  container_name                    = "app"
  container_image                   = "123456789012.dkr.ecr.us-east-1.amazonaws.com/app:latest"
  container_port                    = 8080
  desired_count                     = 2
  task_cpu                          = "256"
  task_memory                       = "512"
  platform_version                  = "LATEST"
  ssl_policy                        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  enable_deletion_protection        = false
  waf_web_acl_arn                   = null
  health_check_path                 = "/health"
  health_check_interval             = 30
  health_check_timeout              = 5
  health_check_healthy_threshold    = 3
  health_check_unhealthy_threshold  = 3
  health_check_matcher              = "200"
  health_check_grace_period_seconds = 60
  log_retention_days                = 30
  container_environment             = []
  container_secrets                 = []
  task_role_policy_json             = null
  deployment_config_name            = "CodeDeployDefault.ECSAllAtOnce"
  auto_rollback_enabled             = true
  auto_rollback_events              = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  deployment_ready_action           = "CONTINUE_DEPLOYMENT"
  deployment_ready_wait_minutes     = 0
  terminate_blue_action             = "TERMINATE"
  blue_termination_wait_minutes     = 5
  create_test_listener              = true
  test_listener_port                = 8443
  wait_for_steady_state             = false
  tags = {
    "Environment" = "test"
    "Project"     = "bluegreen-demo"
  }
}

mock_provider "aws" {}

run "validate_plan" {
  command = plan

  assert {
    condition     = aws_lb.this.internal == false
    error_message = "ALB must be internet-facing (internal = false)"
  }

  assert {
    condition     = aws_lb.this.drop_invalid_header_fields == true
    error_message = "ALB must drop invalid header fields for security"
  }

  assert {
    condition     = aws_lb_listener.http_redirect.default_action[0].type == "redirect"
    error_message = "HTTP listener must redirect to HTTPS"
  }

  assert {
    condition     = aws_ecs_service.this.launch_type == "FARGATE"
    error_message = "ECS service must use FARGATE launch type"
  }

  assert {
    condition     = aws_ecs_service.this.network_configuration[0].assign_public_ip == false
    error_message = "ECS tasks must not have public IPs assigned"
  }

  assert {
    condition     = aws_codedeploy_deployment_group.this.deployment_style[0].deployment_type == "BLUE_GREEN"
    error_message = "CodeDeploy deployment group must use BLUE_GREEN deployment type"
  }

  assert {
    condition     = aws_ecs_task_definition.this.network_mode == "awsvpc"
    error_message = "Task definition must use awsvpc network mode for Fargate"
  }
}
