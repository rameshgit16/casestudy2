provider "aws" {
  region = "ap-south-1"
}

# VPC and Subnets
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Create an Internet Gateway for the VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Create a route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id  # Route all internet-bound traffic through the Internet Gateway
  }
}

# Public Subnet 1
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
}

# Public Subnet 2
resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-south-1b"
}

# Associate public subnets with the public route table
resource "aws_route_table_association" "public_1_association" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2_association" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
}

# Security Groups for EC2 and ALB
resource "aws_security_group" "ec2" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "lb" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Auto Scaling Groups (Blue/Green)
resource "aws_launch_configuration" "blue" {
  name          = "blue-launch-configuration"
  image_id      = "ami-0c2af51e265bd5e0e"  # Update with valid AMI
  instance_type = "t2.micro"
  security_groups = [aws_security_group.ec2.id]
}

resource "aws_launch_configuration" "green" {
  name          = "green-launch-configuration"
  image_id      = "ami-0522ab6e1ddcc7055"  # Update with valid AMI
  instance_type = "t2.micro"
  security_groups = [aws_security_group.ec2.id]
}

resource "aws_autoscaling_group" "blue" {
  desired_capacity     = 1
  max_size             = 2
  min_size             = 1
  launch_configuration = aws_launch_configuration.blue.id
  vpc_zone_identifier  = [aws_subnet.public_1.id]

  tag {
    key                 = "Name"
    value               = "blue-environment"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "green" {
  desired_capacity     = 1
  max_size             = 2
  min_size             = 1
  launch_configuration = aws_launch_configuration.green.id
  vpc_zone_identifier  = [aws_subnet.public_1.id]

  tag {
    key                 = "Name"
    value               = "green-environment"
    propagate_at_launch = true
  }
}

# Application Load Balancer (ALB)
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]  # Two subnets in different AZs

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "blue" {
  name     = "blue-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group" "green" {
  name     = "green-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn  # Initially directing traffic to blue
  }
}

# Route 53 DNS Configuration
resource "aws_route53_zone" "main" {
  name = "blue-green.in.net"
}

resource "aws_route53_record" "blue" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "blue.blue-green.in.net"
  type    = "A"
  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "green" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "green.blue-green.in.net"
  type    = "A"
  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}

# Switch Between Blue/Green Deployment
resource "aws_lb_listener_rule" "green_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green.arn
  }

  condition {
    host_header {
      values = ["green.blue-green.in.net"]
    }
  }
}

# Outputs
output "alb_dns_name" {
  value = aws_lb.app_lb.dns_name
}

output "blue_dns" {
  value = aws_route53_record.blue.fqdn
}

output "green_dns" {
  value = aws_route53_record.green.fqdn
}
