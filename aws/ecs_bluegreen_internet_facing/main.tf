###############################################################################
# Security Group for the Application Load Balancer (internet-facing)
###############################################################################
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Security group for internet-facing ALB - allows HTTPS inbound only"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP redirect from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

###############################################################################
# Security Group for ECS Tasks
###############################################################################
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.name}-ecs-tasks-sg"
  description = "Security group for ECS tasks - allows traffic from ALB only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Traffic from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

###############################################################################
# Application Load Balancer (internet-facing)
###############################################################################
resource "aws_lb" "this" {
  name                       = "${var.name}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = var.enable_deletion_protection
  drop_invalid_header_fields = true
  enable_http2               = true

  tags = var.tags
}

###############################################################################
# Target Groups - Blue and Green
###############################################################################
resource "aws_lb_target_group" "blue" {
  name        = "${var.name}-blue-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = var.health_check_healthy_threshold
    interval            = var.health_check_interval
    matcher             = var.health_check_matcher
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = var.health_check_timeout
    unhealthy_threshold = var.health_check_unhealthy_threshold
  }

  tags = merge(var.tags, { Slot = "blue" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "green" {
  name        = "${var.name}-green-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = var.health_check_healthy_threshold
    interval            = var.health_check_interval
    matcher             = var.health_check_matcher
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = var.health_check_timeout
    unhealthy_threshold = var.health_check_unhealthy_threshold
  }

  tags = merge(var.tags, { Slot = "green" })

  lifecycle {
    create_before_destroy = true
  }
}

###############################################################################
# HTTPS Listener (production traffic)
###############################################################################
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [default_action]
  }
}

###############################################################################
# HTTP -> HTTPS Redirect Listener
###############################################################################
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = var.tags
}

###############################################################################
# Test Listener (used by CodeDeploy to route test traffic to green)
###############################################################################
resource "aws_lb_listener" "test" {
  count             = var.create_test_listener ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = var.test_listener_port
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green.arn
  }

  tags = merge(var.tags, { Purpose = "test-traffic" })

  lifecycle {
    ignore_changes = [default_action]
  }
}

###############################################################################
# WAF Web ACL Association (optional, for internet-facing security)
###############################################################################
resource "aws_wafv2_web_acl_association" "this" {
  count        = var.waf_web_acl_arn != null ? 1 : 0
  resource_arn = aws_lb.this.arn
  web_acl_arn  = var.waf_web_acl_arn
}

###############################################################################
# ECS Task Execution IAM Role
###############################################################################
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.name}-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

###############################################################################
# ECS Task Role (application permissions)
###############################################################################
resource "aws_iam_role" "ecs_task" {
  name = "${var.name}-ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "ecs_task_custom" {
  count  = var.task_role_policy_json != null ? 1 : 0
  name   = "${var.name}-ecs-task-custom-policy"
  role   = aws_iam_role.ecs_task.id
  policy = var.task_role_policy_json
}

###############################################################################
# CloudWatch Log Group
###############################################################################
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

###############################################################################
# ECS Task Definition
###############################################################################
resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = var.container_name
        }
      }
      environment = var.container_environment
      secrets     = var.container_secrets
    }
  ])

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

###############################################################################
# ECS Service (with blue/green CodeDeploy controller)
###############################################################################
resource "aws_ecs_service" "this" {
  name                              = var.name
  cluster                           = var.ecs_cluster_arn
  task_definition                   = aws_ecs_task_definition.this.arn
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  platform_version                  = var.platform_version
  health_check_grace_period_seconds = var.health_check_grace_period_seconds
  enable_ecs_managed_tags           = true
  propagate_tags                    = "SERVICE"
  wait_for_steady_state             = var.wait_for_steady_state

  network_configuration {
    assign_public_ip = false
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      task_definition,
      load_balancer,
      desired_count,
    ]
  }

  depends_on = [
    aws_lb_listener.https,
    aws_iam_role_policy_attachment.ecs_task_execution_managed,
  ]
}

###############################################################################
# CodeDeploy Application and Deployment Group for Blue/Green
###############################################################################
resource "aws_codedeploy_app" "this" {
  compute_platform = "ECS"
  name             = var.name
  tags             = var.tags
}

resource "aws_iam_role" "codedeploy" {
  name = "${var.name}-codedeploy-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "codedeploy_ecs" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

resource "aws_codedeploy_deployment_group" "this" {
  app_name               = aws_codedeploy_app.this.name
  deployment_config_name = var.deployment_config_name
  deployment_group_name  = "${var.name}-dg"
  service_role_arn       = aws_iam_role.codedeploy.arn

  auto_rollback_configuration {
    enabled = var.auto_rollback_enabled
    events  = var.auto_rollback_events
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout    = var.deployment_ready_action
      wait_time_in_minutes = var.deployment_ready_wait_minutes
    }
    terminate_blue_instances_on_deployment_success {
      action                           = var.terminate_blue_action
      termination_wait_time_in_minutes = var.blue_termination_wait_minutes
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = var.ecs_cluster_name
    service_name = aws_ecs_service.this.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.https.arn]
      }

      dynamic "test_traffic_route" {
        for_each = var.create_test_listener ? [1] : []
        content {
          listener_arns = [aws_lb_listener.test[0].arn]
        }
      }

      target_group {
        name = aws_lb_target_group.blue.name
      }

      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }

  tags = var.tags
}
