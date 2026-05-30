# basic.tftest.hcl - Unit tests for aws_ecs_blue_green_service module
# Uses mock_provider + override_resource inside run blocks (OpenTofu 1.8+ syntax).

mock_provider "aws" {}

variables {
  name                              = "test-svc"
  vpc_id                            = "vpc-00000000000000001"
  public_subnet_ids                 = ["subnet-00000000000000001", "subnet-00000000000000002"]
  private_subnet_ids                = ["subnet-00000000000000003", "subnet-00000000000000004"]
  cluster_arn                       = "arn:aws:ecs:us-east-1:123456789012:cluster/test-cluster"
  container_definitions             = "[{\"name\":\"app\",\"image\":\"nginx:latest\",\"essential\":true,\"portMappings\":[{\"containerPort\":8080}]}]"
  container_name                    = "app"
  container_port                    = 8080
  certificate_arn                   = "arn:aws:acm:us-east-1:123456789012:certificate/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  execution_role_arn                = "arn:aws:iam::123456789012:role/ecs-execution-role"
  task_role_arn                     = "arn:aws:iam::123456789012:role/ecs-task-role"
  task_cpu                          = "256"
  task_memory                       = "512"
  launch_type                       = "FARGATE"
  platform_version                  = "LATEST"
  cpu_architecture                  = "X86_64"
  operating_system_family           = "LINUX"
  desired_count                     = 1
  health_check_grace_period_seconds = 30
  wait_for_steady_state             = false
  ssl_policy                        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  enable_deletion_protection        = false
  alb_idle_timeout                  = 60
  alb_access_logs_bucket            = ""
  alb_access_logs_prefix            = ""
  deregistration_delay              = 30
  health_check_path                 = "/health"
  health_check_healthy_threshold    = 3
  health_check_unhealthy_threshold  = 3
  health_check_interval             = 30
  health_check_timeout              = 5
  health_check_matcher              = "200"
  tags                              = { Environment = "test" }
}

# Test 1: ALB is internet-facing with correct security settings
run "basic_plan" {
  command = plan

  override_resource {
    target = aws_alb.this
    values = {
      arn      = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/test-svc-alb/1234567890abcdef"
      dns_name = "test-svc-alb-1234567890.us-east-1.elb.amazonaws.com"
      zone_id  = "Z35SXDOTRQ7X7K"
    }
  }

  override_resource {
    target = aws_alb_target_group.blue
    values = {
      arn  = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test-svc-blue-tg/1234567890abcdef"
      name = "test-svc-blue-tg"
    }
  }

  override_resource {
    target = aws_alb_target_group.green
    values = {
      arn  = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test-svc-green-tg/abcdef1234567890"
      name = "test-svc-green-tg"
    }
  }

  override_resource {
    target = aws_ecs_task_definition.this
    values = {
      arn                  = "arn:aws:ecs:us-east-1:123456789012:task-definition/test-svc:1"
      arn_without_revision = "arn:aws:ecs:us-east-1:123456789012:task-definition/test-svc"
      revision             = 1
      family               = "test-svc"
    }
  }

  override_resource {
    target = aws_security_group.alb
    values = {
      id  = "sg-alb00000000000001"
      arn = "arn:aws:ec2:us-east-1:123456789012:security-group/sg-alb00000000000001"
    }
  }

  override_resource {
    target = aws_security_group.ecs_tasks
    values = {
      id  = "sg-ecs00000000000001"
      arn = "arn:aws:ec2:us-east-1:123456789012:security-group/sg-ecs00000000000001"
    }
  }

  assert {
    condition     = aws_alb.this.internal == false
    error_message = "ALB must be internet-facing (internal=false)"
  }

  assert {
    condition     = aws_alb.this.drop_invalid_header_fields == true
    error_message = "ALB must drop invalid header fields for security"
  }

  assert {
    condition     = aws_alb.this.enable_deletion_protection == false
    error_message = "Deletion protection should reflect input variable"
  }

  assert {
    condition     = aws_security_group.alb.name == "test-svc-alb-sg"
    error_message = "ALB security group name must be prefixed with var.name"
  }

  assert {
    condition     = aws_security_group.ecs_tasks.name == "test-svc-ecs-tasks-sg"
    error_message = "ECS tasks security group name must be prefixed with var.name"
  }

  assert {
    condition     = aws_alb_target_group.blue.target_type == "ip"
    error_message = "Blue TG must use ip target type for Fargate"
  }

  assert {
    condition     = aws_alb_target_group.green.target_type == "ip"
    error_message = "Green TG must use ip target type for Fargate"
  }

  assert {
    condition     = aws_alb_target_group.blue.port == 8080
    error_message = "Blue TG port must match container_port"
  }

  assert {
    condition     = aws_alb_target_group.green.port == 8080
    error_message = "Green TG port must match container_port"
  }

  assert {
    condition     = aws_alb_listener.https_prod.port == 443
    error_message = "Production listener must be on port 443"
  }

  assert {
    condition     = aws_alb_listener.https_test.port == 8443
    error_message = "Test listener must be on port 8443"
  }

  assert {
    condition     = aws_alb_listener.https_prod.ssl_policy == "ELBSecurityPolicy-TLS13-1-2-2021-06"
    error_message = "Production listener must use TLS 1.3 policy"
  }

  assert {
    condition     = aws_ecs_service.this.deployment_controller[0].type == "CODE_DEPLOY"
    error_message = "ECS service must use CODE_DEPLOY deployment controller for blue/green"
  }

  assert {
    condition     = length(aws_ecs_service.this.network_configuration[0].subnets) == 2
    error_message = "ECS service must be placed in private subnets"
  }

  assert {
    condition     = aws_ecs_service.this.network_configuration[0].assign_public_ip == false
    error_message = "ECS tasks must not have public IPs"
  }
}
