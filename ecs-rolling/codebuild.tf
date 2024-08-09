resource "aws_iam_role" "build" {
  name = "${var.project_name}-role-build"
  assume_role_policy = data.aws_iam_policy_document.build-asm.json
}

resource "aws_iam_policy" "build" {
  name = "${var.project_name}-policy-build"
  policy = data.aws_iam_policy_document.build.json
}

resource "aws_iam_role_policy_attachment" "build" {
  role = aws_iam_role.build.id
  policy_arn = aws_iam_policy.build.arn
}

data "aws_iam_policy_document" "build-asm" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "build" {
  statement {
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream"
    ]

    resources = [
      "${aws_cloudwatch_log_group.build.arn}:log-stream:*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.artifacts.arn}/*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ecr:CompleteLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:InitiateLayerUpload",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage"
    ]

    resources = [
      aws_ecr_repository.repo.arn
    ]
  }
}

resource "aws_cloudwatch_log_group" "build" {
  name = "${var.project_name}-build"
}

resource "aws_codebuild_project" "build" {
  name = "${var.project_name}-build"
  service_role = aws_iam_role.build.arn

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image_pull_credentials_type = "CODEBUILD"
    image = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name = "REPOSITORY_NAME"
      value = aws_ecr_repository.repo.name
    }

    environment_variable {
      name = "CONTAINER_NAME"
      value = "${var.project_name}-app"
    }
  }

  source {
    type = "CODEPIPELINE"
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.build.name
    }
  }
}
