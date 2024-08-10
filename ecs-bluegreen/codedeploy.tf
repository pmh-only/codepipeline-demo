resource "aws_iam_role" "deploy" {
  name = "${var.project_name}-role-deploy"
  assume_role_policy = data.aws_iam_policy_document.deploy-asm.json
}

resource "aws_iam_policy" "deploy" {
  name = "${var.project_name}-policy-deploy"
  policy = data.aws_iam_policy_document.deploy.json
}

resource "aws_iam_role_policy_attachment" "deploy" {
  role = aws_iam_role.deploy.id
  policy_arn = aws_iam_policy.deploy.arn
}

resource "aws_iam_role_policy_attachment" "deploy-2" {
  role = aws_iam_role.deploy.id
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

data "aws_iam_policy_document" "deploy-asm" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "deploy" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.artifacts.arn}/*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      module.ecs_service.tasks_iam_role_arn,
      module.ecs_service.task_exec_iam_role_arn
    ]
  }
}

resource "aws_codedeploy_app" "deploy" {
  name = "${var.project_name}-deploy"
  compute_platform = "ECS"
}

resource "aws_codedeploy_deployment_config" "deploy" {
  deployment_config_name = "${var.project_name}-deploy"
  compute_platform = "ECS"
  
  traffic_routing_config {
    type = "TimeBasedLinear"

    time_based_linear {
      interval = 1
      percentage = 10
    }
  }
}

resource "aws_codedeploy_deployment_group" "deploy" {
  app_name = aws_codedeploy_app.deploy.name
  deployment_group_name = "${var.project_name}-deploy"
  service_role_arn = aws_iam_role.deploy.arn
  deployment_config_name = aws_codedeploy_deployment_config.deploy.deployment_config_name
  
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = module.ecs.cluster_name
    service_name = module.ecs_service.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [
          module.alb.listeners.listener-prod.arn
        ]
      }

      test_traffic_route {
        listener_arns = [
          module.alb.listeners.listener-test.arn
        ]
      }

      target_group {
        name = module.alb.target_groups.target-blue.name
      }

      target_group {
        name = module.alb.target_groups.target-green.name
      }
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {  
    deployment_ready_option {
      action_on_timeout    = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action = "TERMINATE"
      termination_wait_time_in_minutes = 1
    }
  }
}
