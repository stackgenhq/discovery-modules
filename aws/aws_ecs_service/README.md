# aws_ecs_service — Blue/Green ECS Discovery Module

This discovery module provisions an AWS ECS Service configured for **blue/green deployments** via AWS CodeDeploy. It is designed for internet-facing microservices with security best practices enforced.

## Security requirements enforced

- `assign_public_ip = false` — tasks run in private subnets; internet traffic routes through an ALB
- `launch_type = "FARGATE"` — no EC2 instance management surface
- `deployment_controller.type = "CODE_DEPLOY"` — enables blue/green zero-downtime deployments

## Usage

```hcl
module "ecs_service" {
  source = "aws/aws_ecs_service"

  name            = "my-api"
  cluster         = aws_ecs_cluster.main.arn
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"

  network_configuration = [{
    assign_public_ip = false
    subnets          = module.vpc.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
  }]

  load_balancer = [{
    elb_name         = null
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = "app"
    container_port   = 8080
  }]

  deployment_controller = [{
    type = "CODE_DEPLOY"
  }]

  tags = { Environment = "production" }
}
```

## Inputs / Outputs

See `variables.tf.json` and `outputs.tf.json`.

Originated from: https://github.com/stackgenhq/discovery-modules/issues/9
