# Define AWS provider
provider "aws" {
  region = "ap-south-1"
}

# Create ALBs for blue and green environments
resource "aws_lb" "blue" {
  name               = "blue-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = ["subnet-1", "subnet-2"]
  security_groups    = ["launch-wizard-1"]
}

resource "aws_lb" "green" {
  name               = "green-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = ["subnet-1", "subnet-2"]
  security_groups    = ["launch-wizard-1"]
}

# Create Route 53 DNS records
resource "aws_route53_record" "blue_alias" {
  zone_id = "Z07619922B5B5NYRVPYJ5"
  name    = "blue.blue-green.in.net"
  type    = "A"
  alias {
    name                   = aws_lb.blue.dns_name
    zone_id                = aws_lb.blue.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "green_alias" {
  zone_id = "Z07689963OQX6JK2L1F3F"
  name    = "green.blue-green.in.net"
  type    = "A"
  alias {
    name                   = aws_lb.green.dns_name
    zone_id                = aws_lb.green.zone_id
    evaluate_target_health = true
  }
}

# Define Auto Scaling Groups for blue and green environments
resource "aws_autoscaling_group" "green" {
  name             = "green-asg"
  min_size         = 1
  max_size         = 3
  desired_capacity = 2
  launch_template {
    id = "lt-050f4e4a4ffb27c58"
  }
  vpc_zone_identifier = ["subnet-1", "subnet-2"]
}

resource "aws_autoscaling_group" "blue" {
  name             = "blue-asg"
  min_size         = 1
  max_size         = 3
  desired_capacity = 2
  launch_template {
    id = "	lt-0fabed2daacb7e860"
  }
  vpc_zone_identifier = ["subnet-1", "subnet-2"]
}

# Configure SSL certificate for ALB listeners
resource "aws_acm_certificate" "ssl_cert" {
  domain_name       = "blue-green.com"
  validation_method = "DNS"

  tags = {
    Name = "example-com-cert"
  }
}

resource "aws_lb_listener" "blue_https" {
  load_balancer_arn = aws_lb.blue.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn  = "arn:aws:acm:ap-south-1:783764581360:certificate/dff3067e-54aa-4fc8-8393-a735e7abc706"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
}

resource "aws_lb_listener" "green_https" {
  load_balancer_arn = aws_lb.green.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn  = "arn:aws:acm:ap-south-1:783764581360:certificate/dff3067e-54aa-4fc8-8393-a735e7abc706"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green.arn
  }
}

# Define Target Groups for blue and green environments
resource "aws_lb_target_group" "blue" {
  name     = "blue-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-0a9ffdd77689f21d4"
}

resource "aws_lb_target_group" "green" {
  name     = "green-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-0a9ffdd77689f21d4"
}

# Define Route 53 DNS records pointing to ALB endpoints
resource "aws_route53_record" "blue_dns" {
  zone_id = "Z07619922B5B5NYRVPYJ5"
  name    = "blue.blue-green.in.net"
  type    = "A"
  alias {
    name                   = aws_lb.blue.dns_name
    zone_id                = aws_lb.blue.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "green_dns" {
  zone_id = "Z07689963OQX6JK2L1F3F"
  name    = "green.blue-green.in.net"
  type    = "A"
  alias {
    name                   = aws_lb.green.dns_name
    zone_id                = aws_lb.green.zone_id
    evaluate_target_health = true
  }
}
