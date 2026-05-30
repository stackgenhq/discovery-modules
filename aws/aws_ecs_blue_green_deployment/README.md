# aws_ecs_blue_green_deployment

Discovery module for blue/green deployments of internet-facing microservices using AWS ECS.

This module provisions an `aws_ecs_service` resource configured with the `CODE_DEPLOY` deployment
controller, enabling zero-downtime blue/green deployments via AWS CodeDeploy. It enforces private
networking (`assign_public_ip = false`) and integrates with an Application Load Balancer target group.

## Security requirements
- No public IP assignment on ECS tasks
- Security groups must be explicitly provided (no default SG)
- Deployment controller is locked to `CODE_DEPLOY` for controlled rollouts

## Usage
See `.stackgen/stackgen.yaml` for StackGen UI metadata.

Resolves: stackgenhq/discovery-modules#9
