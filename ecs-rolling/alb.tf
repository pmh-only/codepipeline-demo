module "alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "${var.project_name}-alb"
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "tcp"
      from_port = 8080
      to_port = 8080
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  listeners = {
    listener = {
      name = "${var.project_name}-listener"
      port            = 80
      protocol        = "HTTP"

      forward = {
        target_group_key = "target"
      }
    }
  }

  target_groups = {
    target = {
      create_attachment = false
      name      = "${var.project_name}-tgp"
      protocol         = "HTTP"
      port             = 8080
      target_type      = "ip"
      deregistration_delay              = 10

      health_check = {
        enabled             = true
        interval            = 30
        path                = "/healthz"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-399"
      }
    }
  }
}
