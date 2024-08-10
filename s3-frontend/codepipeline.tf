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
      "${aws_s3_bucket.artifacts.arn}/*",
      "${aws_s3_bucket.bucket.arn}/*"
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
      "kms:GenerateDataKey"
    ]

    resources = [
      aws_kms_key.bucket_encryption.arn
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "lambda:InvokeFunction"
    ]

    resources = [
      module.lambda_function.lambda_function_arn
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
      name = "Deploy"
      category = "Deploy"
      owner = "AWS"
      provider = "S3"
      version = "1"

      input_artifacts = ["build_output"]

      configuration = {
        BucketName = aws_s3_bucket.bucket.bucket
        Extract = true
        KMSEncryptionKeyARN = aws_kms_key.bucket_encryption.arn
      }
    }
  }

  stage {
    name = "Invalidate"

    action {
      name = "Invalidate"
      category = "Invoke"
      owner = "AWS"
      provider = "Lambda"
      version = "1"

      configuration = {
        FunctionName = module.lambda_function.lambda_function_name
      }
    }
  }
}
