data "aws_ssm_parameter" "bottlerocket" {
  name = "/aws/service/bottlerocket/aws-ecs-2/x86_64/latest/image_id"
}

resource "aws_security_group" "instance" {
  vpc_id = module.vpc.vpc_id
  name = "${var.project_name}-sg-instance"

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_iam_policy" "instance" {
  name = "${var.project_name}-policy-instance"
  policy = data.aws_iam_policy_document.instance.json
}

data "aws_iam_policy_document" "instance" {
  statement {
    actions = [
      "ecs:UpdateContainerInstanceState"
    ]

    resources = ["*"]
  }
}

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"

  name = "${var.project_name}-asg"

  min_size                  = 4
  max_size                  = 16
  desired_capacity          = 4
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"
  vpc_zone_identifier       = module.vpc.private_subnets

  launch_template_name        = "${var.project_name}-template"
  launch_template_description = "Launch template example"
  update_default_version      = true

  image_id          = data.aws_ssm_parameter.bottlerocket.value
  instance_type     = "c5.large"
  ebs_optimized     = true
  enable_monitoring = true

  user_data = base64encode(<<-EOF
    [settings.ecs]
    cluster = "${module.ecs.cluster_name}"
    enable-spot-instance-draining = true
  EOF
  )

  create_iam_instance_profile = true
  iam_role_name               = "${var.project_name}-role-instance"
  iam_role_description        = "IAM role for instance"
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    instancePolicy = aws_iam_policy.instance.arn
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

  use_mixed_instances_policy = true
  mixed_instances_policy = {
    instances_distribution = {
      on_demand_base_capacity                  = 1
      on_demand_percentage_above_base_capacity = 25
      spot_allocation_strategy                 = "lowest-price"
    }

    override = [
      {
        instance_type     = "c5.large"
      },
      {
        instance_type     = "c5.xlarge"
      },
      {
        instance_type     = "c5.2xlarge"
      }
    ]
  }
  
  tag_specifications = [
    {
      resource_type = "instance"
      tags          = { Project=var.project_name }
    },
    {
      resource_type = "volume"
      tags          = { Project=var.project_name }
    },
    {
      resource_type = "network-interface"
      tags          = { Project=var.project_name }
    }
  ]

  depends_on = [
    module.vpc
  ]
}
