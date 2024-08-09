resource "aws_iam_role" "pipeline" {
  name = "${var.project_name}-role-pipeline"
  assume_role_policy = data.aws_iam_policy_document.pipeline-asm.json

}

data "aws_iam_policy_document" "pipeline-asm" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "pipeline" {
  statement {
    effect = "Allow"

    actions = [
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:UploadArchive",
      "codecommit:GetUploadArchiveStatus"
    ]

    resources = [
      aws_codecommit_repository.repo.arn
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.artifacts.arn}/*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "codebuild:StartBuild",
      "codebuild:BatchGetBuilds"
    ]

    resources = [
      aws_codebuild_project.build.arn
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:TagResource"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ecs:UpdateService",
      "ecs:ListTasks",
      "ecs:DescribeTasks",
      "ecs:DescribeServices"
    ]

    resources = [ "*" ]
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      module.ecs_service_ec2.task_exec_iam_role_arn,
      module.ecs_service_ec2.tasks_iam_role_arn,
      module.ecs_service_fargate.task_exec_iam_role_arn,
      module.ecs_service_fargate.tasks_iam_role_arn,
    ]
  }
}

resource "aws_iam_policy" "pipeline" {
  name = "${var.project_name}-policy-pipeline"
  policy = data.aws_iam_policy_document.pipeline.json
}

resource "aws_iam_role_policy_attachment" "pipeline" {
  role = aws_iam_role.pipeline.id
  policy_arn = aws_iam_policy.pipeline.arn
}

resource "aws_codepipeline" "pipeline" {
  name = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.pipeline.arn

  pipeline_type = "V2"

  artifact_store {
    type = "S3"
    location = aws_s3_bucket.artifacts.bucket
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = aws_codecommit_repository.repo.repository_name
        BranchName = "main"
        PollForSourceChanges = "false"
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy-EC2"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ClusterName = module.ecs.cluster_name
        ServiceName = module.ecs_service_ec2.name
        FileName = "imagedefinitions.json"
        DeploymentTimeout = "15"
      }
    }

    action {
      name            = "Deploy-Fargate"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ClusterName = module.ecs.cluster_name
        ServiceName = module.ecs_service_fargate.name
        FileName = "imagedefinitions.json"
        DeploymentTimeout = "15"
      }
    }
  }
}
