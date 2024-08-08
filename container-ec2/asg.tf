data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

resource "aws_iam_policy" "instance" {
  name = "${var.project_name}-policy-instance"
  policy = data.aws_iam_policy_document.instance.json
}

data "aws_iam_policy_document" "instance" {
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
      "ecr:GetAuthorizationToken"
    ]

    resources = [
      "*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]

    resources = [
      aws_ecr_repository.repo.arn
    ]
  }
}

resource "aws_security_group" "instance" {
  vpc_id = module.vpc.vpc_id
  name = "${var.project_name}-sg-instance"
  
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    security_groups = [
      module.alb.security_group_id
    ]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"

  name = "${var.project_name}-asg"

  min_size                  = 2
  max_size                  = 16
  desired_capacity          = 2
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"
  vpc_zone_identifier       = module.vpc.private_subnets

  launch_template_name        = "${var.project_name}-template"
  launch_template_description = "Launch template example"
  update_default_version      = true

  image_id          = data.aws_ssm_parameter.al2023.value
  instance_type     = "c5.large"
  ebs_optimized     = true
  enable_monitoring = true

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update
    yum install -y ruby wget docker

    wget https://aws-codedeploy-${var.region}.s3.${var.region}.amazonaws.com/latest/install -O /tmp/codedeploy-agent-install
    chmod +x /tmp/codedeploy-agent-install
    /tmp/codedeploy-agent-install auto
    systemctl enable --now codedeploy-agent
    systemctl enable --now docker
  EOF
  )

  create_iam_instance_profile = true
  iam_role_name               = "${var.project_name}-role-instance"
  iam_role_description        = "IAM role for instance"
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    CodePipelineArtifact = aws_iam_policy.instance.arn
  }

  block_device_mappings = [
    {
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 8
        volume_type           = "gp2"
      }
    }
  ]

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  network_interfaces = [
    {
      delete_on_termination = true
      description           = "eth0"
      device_index          = 0
      security_groups       = [
        aws_security_group.instance.id
      ]
    }
  ]

  depends_on = [
    module.vpc
  ]
}
