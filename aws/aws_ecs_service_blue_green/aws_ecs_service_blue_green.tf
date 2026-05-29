resource "aws_ecs_service" "this" {
  name                               = var.name
  cluster                            = var.cluster
  task_definition                    = var.task_definition
  desired_count                      = var.desired_count
  launch_type                        = var.launch_type
  platform_version                   = var.platform_version
  scheduling_strategy                = var.scheduling_strategy
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  enable_ecs_managed_tags            = var.enable_ecs_managed_tags
  enable_execute_command             = var.enable_execute_command
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
  propagate_tags                     = var.propagate_tags
  wait_for_steady_state              = var.wait_for_steady_state
  tags                               = var.tags

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  dynamic "network_configuration" {
    for_each = var.network_configuration
    content {
      assign_public_ip = network_configuration.value.assign_public_ip
      subnets          = network_configuration.value.subnets
      security_groups  = network_configuration.value.security_groups
    }
  }

  dynamic "load_balancer" {
    for_each = var.load_balancer
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy
    content {
      base              = capacity_provider_strategy.value.base
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
    }
  }

  dynamic "service_registries" {
    for_each = var.service_registries
    content {
      registry_arn   = service_registries.value.registry_arn
      container_name = service_registries.value.container_name
      container_port = service_registries.value.container_port
      port           = service_registries.value.port
    }
  }

  dynamic "timeouts" {
    for_each = var.timeouts != null ? [var.timeouts] : []
    content {
      create = lookup(timeouts.value, "create", null)
      delete = lookup(timeouts.value, "delete", null)
      update = lookup(timeouts.value, "update", null)
    }
  }

  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }
}
