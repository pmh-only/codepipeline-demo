data "aws_ssm_parameter" "fluentbit" {
  name = "/aws/service/aws-for-fluent-bit/stable"
}

resource "aws_cloudwatch_log_group" "ecs" {
  name = "/aws/ecs/containerinsights/${module.ecs.cluster_name}/application"
}

resource "aws_cloudwatch_log_group" "ecs-exec" {
  name = "/aws/ecs/${var.project_name}-exec-log"
}

module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  cluster_name = "${var.project_name}-cluster"

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/${var.project_name}-exec-log"
      }
    }
  }

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 75
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 25
      }
    }
  }
}
