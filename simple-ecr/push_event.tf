resource "aws_iam_role" "event" {
  name = "${var.project_name}-role-event"
  assume_role_policy = data.aws_iam_policy_document.event-asm.json
}

data "aws_iam_policy_document" "event-asm" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "event" {
  statement {
    actions = [
      "iam:PassRole",
      "codepipeline:*"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "event" {
  name = "${var.project_name}-policy-event"
  policy = data.aws_iam_policy_document.event.json
}

resource "aws_iam_role_policy_attachment" "event" {
  role = aws_iam_role.event.id
  policy_arn = aws_iam_policy.event.arn
}

resource "aws_cloudwatch_event_rule" "event" {
  name = "${var.project_name}-pushevent"
  event_pattern = <<EOF
    {
      "source": [ "aws.codecommit" ],
      "detail-type": [ "CodeCommit Repository State Change" ],
      "resources": [ "${aws_codecommit_repository.repo.arn}" ],
      "detail": {
        "event": [
          "referenceCreated",
          "referenceUpdated"
          ],
        "referenceType":["branch"],
        "referenceName": ["main"]
      }
    }
  EOF
}

resource "aws_cloudwatch_event_target" "event" {
  target_id = "${var.project_name}-pushtarget"
  rule = aws_cloudwatch_event_rule.event.name
  arn = aws_codepipeline.pipeline.arn
  role_arn = aws_iam_role.event.arn
}
