##############################################################################
# ALB Security Group (internet-facing, HTTPS only)
##############################################################################
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Security group for the internet-facing ALB – allows HTTPS (443) and test traffic (8443) inbound from the internet"
  vpc_id      = var.vpc_id

  ingress {
    description      = "HTTPS production traffic from internet"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }

  ingress {
    description      = "HTTPS test traffic from internet (blue/green test listener)"
    from_port        = 8443
    to_port          = 8443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }

  egress {
    description      = "All outbound"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }

  tags = merge(var.tags, { Name = "${var.name}-alb-sg" })
}

##############################################################################
# ECS Task Security Group (private, only accepts traffic from ALB SG)
##############################################################################
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.name}-ecs-tasks-sg"
  description = "Security group for ECS tasks – allows inbound only from the ALB security group"
  vpc_id      = var.vpc_id

  ingress {
    description      = "Traffic from ALB only"
    from_port        = var.container_port
    to_port          = var.container_port
    protocol         = "tcp"
    cidr_blocks      = []
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = [aws_security_group.alb.id]
    self             = false
  }

  egress {
    description      = "All outbound (for ECR pulls, SSM, etc.)"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }

  tags = merge(var.tags, { Name = "${var.name}-ecs-tasks-sg" })
}

##############################################################################
# Internet-Facing Application Load Balancer
##############################################################################
resource "aws_alb" "this" {
  name                       = "${var.name}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = var.enable_deletion_protection
  enable_http2               = true
  idle_timeout               = var.alb_idle_timeout
  drop_invalid_header_fields = true

  dynamic "access_logs" {
    for_each = var.alb_access_logs_bucket != "" ? [1] : []
    content {
      bucket  = var.alb_access_logs_bucket
      prefix  = var.alb_access_logs_prefix
      enabled = true
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-alb" })
}

##############################################################################
# Blue Target Group
##############################################################################
resource "aws_alb_target_group" "blue" {
  name                 = "${var.name}-blue-tg"
  port                 = var.container_port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = var.deregistration_delay

  dynamic "health_check" {
    for_each = [1]
    content {
      enabled             = true
      path                = var.health_check_path
      port                = "traffic-port"
      protocol            = "HTTP"
      healthy_threshold   = var.health_check_healthy_threshold
      unhealthy_threshold = var.health_check_unhealthy_threshold
      interval            = var.health_check_interval
      timeout             = var.health_check_timeout
      matcher             = var.health_check_matcher
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-blue-tg" })

  lifecycle {
    create_before_destroy = true
  }
}

##############################################################################
# Green Target Group
##############################################################################
resource "aws_alb_target_group" "green" {
  name                 = "${var.name}-green-tg"
  port                 = var.container_port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = var.deregistration_delay

  dynamic "health_check" {
    for_each = [1]
    content {
      enabled             = true
      path                = var.health_check_path
      port                = "traffic-port"
      protocol            = "HTTP"
      healthy_threshold   = var.health_check_healthy_threshold
      unhealthy_threshold = var.health_check_unhealthy_threshold
      interval            = var.health_check_interval
      timeout             = var.health_check_timeout
      matcher             = var.health_check_matcher
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-green-tg" })

  lifecycle {
    create_before_destroy = true
  }
}

##############################################################################
# HTTPS Redirect Listener (HTTP 80 -> HTTPS 443)
##############################################################################
resource "aws_alb_listener" "http_redirect" {
  load_balancer_arn = aws_alb.this.arn
  port              = 80
  protocol          = "HTTP"
  tags              = merge(var.tags, { Name = "${var.name}-http-redirect" })

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

##############################################################################
# Production HTTPS Listener (port 443) – initially forwards to Blue TG
##############################################################################
resource "aws_alb_listener" "https_prod" {
  load_balancer_arn = aws_alb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn
  tags              = merge(var.tags, { Name = "${var.name}-https-prod" })

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.blue.arn
  }

  lifecycle {
    # CodeDeploy manages the target group; ignore changes after initial create
    ignore_changes = [default_action]
  }
}

##############################################################################
# Test HTTPS Listener (port 8443) – used by CodeDeploy to validate green
##############################################################################
resource "aws_alb_listener" "https_test" {
  load_balancer_arn = aws_alb.this.arn
  port              = 8443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn
  tags              = merge(var.tags, { Name = "${var.name}-https-test" })

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.green.arn
  }

  lifecycle {
    ignore_changes = [default_action]
  }
}

##############################################################################
# ECS Task Definition
##############################################################################
resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  container_definitions    = var.container_definitions
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = "awsvpc"
  requires_compatibilities = var.launch_type == "FARGATE" ? ["FARGATE"] : ["EC2"]
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn != "" ? var.task_role_arn : null
  tags                     = var.tags

  dynamic "runtime_platform" {
    for_each = var.launch_type == "FARGATE" ? [1] : []
    content {
      cpu_architecture        = var.cpu_architecture
      operating_system_family = var.operating_system_family
    }
  }
}

##############################################################################
# ECS Service (CODE_DEPLOY controller for blue/green)
##############################################################################
resource "aws_ecs_service" "this" {
  name                               = var.name
  cluster                            = var.cluster_arn
  task_definition                    = aws_ecs_task_definition.this.arn
  desired_count                      = var.desired_count
  launch_type                        = var.launch_type
  platform_version                   = var.launch_type == "FARGATE" ? var.platform_version : null
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
  wait_for_steady_state              = var.wait_for_steady_state
  tags                               = var.tags

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.blue.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  lifecycle {
    # CodeDeploy manages task definition and load balancer after initial deploy
    ignore_changes = [task_definition, load_balancer]
  }
}
