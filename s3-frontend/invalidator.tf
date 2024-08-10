module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "${var.project_name}-invalidator"
  handler       = "index.lambda_handler"
  runtime       = "python3.12"

  attach_policy_json = true
  policy_json = data.aws_iam_policy_document.lambda.json

  environment_variables = {
    DISTRIBUTION_ID = module.cloudfront.cloudfront_distribution_id
  }

  source_path = "${path.module}/invalidator"
}

data "aws_iam_policy_document" "lambda" {
  statement {
    effect = "Allow"

    actions = [
      "codepipeline:PutJobSuccessResult",
      "codepipeline:PutJobFailureResult"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "cloudfront:CreateInvalidation"
    ]

    resources = [
      module.cloudfront.cloudfront_distribution_arn
    ]
  }
}
