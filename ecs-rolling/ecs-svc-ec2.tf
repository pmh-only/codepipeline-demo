module "ecs_service_ec2" {
  source = "terraform-aws-modules/ecs/aws//modules/service"
  
  name        = "${var.project_name}-service-ec2"
  cluster_arn = module.ecs.cluster_arn

  cpu    = 512
  memory = 1024
  launch_type = "EC2"
  requires_compatibilities = ["EC2"]
  ignore_task_definition_changes = true


  tasks_iam_role_statements = [
    {
      effect = "Allow"
      actions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]
      resources = ["*"]
    }
  ]

  container_definitions = {
    fluent-bit = {
      cpu       = 256
      memory    = 512
      essential = true
      image     = data.aws_ssm_parameter.fluentbit.value
      firelens_configuration = {
        type = "fluentbit"
      }
      memory_reservation = 50
    }

    "${var.project_name}-app" = {
      cpu       = 256
      memory    = 512
      essential = true
      image     = "${aws_ecr_repository.repo.repository_url}:unknown"
      port_mappings = [
        {
          name          = "${var.project_name}-app-port"
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      readonly_root_filesystem = false

      health_check = {
        command = [
          "CMD-SHELL",
          "curl -fLs http://localhost:8080/healthz > /dev/null || exit 1"
        ]

        interval = 5
        timeout = 2
        retries = 1
        startPeriod = 0
      }

      dependencies = [{
        containerName = "fluent-bit"
        condition     = "START"
      }]

      enable_cloudwatch_logging = false
      log_configuration = {
        logDriver = "awsfirelens"
        options = {
          Name                    = "cloudwatch"
          region                  = var.region
          log_key = "log"
          log_group_name = "/aws/ecs/containerinsights/$(ecs_cluster)/application"
          log_stream_name = "$(ecs_task_id)"
          retry_limit = "2"
        }
      }
      memory_reservation = 100
    }
  }

  load_balancer = {
    service = {
      target_group_arn = module.alb.target_groups.target.arn
      container_name   = "${var.project_name}-app"
      container_port   = 8080
    }
  }


  enable_autoscaling = true
  autoscaling_min_capacity = 2
  desired_count = 2
  autoscaling_max_capacity = 64

  subnet_ids = module.vpc.private_subnets
  security_group_rules = {
    alb_ingress_8080 = {
      type = "ingress"
      from_port = 8080
      to_port = 8080
      protocol = "tcp"
      source_security_group_id = module.alb.security_group_id
    }
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}
