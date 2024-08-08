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
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
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
      module.asg.iam_role_arn
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
      "ec2:CreateTags"
    ]

    resources = ["*"]
  }
}

resource "aws_codedeploy_app" "deploy" {
  name = "${var.project_name}-deploy"
}

resource "aws_codedeploy_deployment_config" "deploy" {
  deployment_config_name = "${var.project_name}-deploy"
  
  minimum_healthy_hosts {
    type = "HOST_COUNT"
    value = 1
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


  load_balancer_info {
    target_group_info {
      name = module.alb.target_groups.target.name
    }
  }

  autoscaling_groups = [
    module.asg.autoscaling_group_name
  ]

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {  
    deployment_ready_option {
      action_on_timeout    = "CONTINUE_DEPLOYMENT"
    }

    green_fleet_provisioning_option {
      action = "COPY_AUTO_SCALING_GROUP"
    }

    terminate_blue_instances_on_deployment_success {
      action = "TERMINATE"
      termination_wait_time_in_minutes = 0
    }
  }
}
