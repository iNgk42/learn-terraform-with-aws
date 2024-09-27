#########################
# Main configuration file
#########################

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-3"
}

# Datasources
####################################

# Fetch ubuntu image from aws
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Fetch default vpc
data "aws_vpc" "default" {
  default = true
}

# Fetch subnets of default vpc
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security groups
####################################

# Define security group to allow traffic to our EC2 instance
resource "aws_security_group" "webserver_sg" {
  name        = "webserver_sg"
  description = "Allow traffic from and to the webserver"
}

resource "aws_vpc_security_group_ingress_rule" "allow_traffic_to_webserver" {
  security_group_id = aws_security_group.webserver_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = var.webserver_port
  ip_protocol       = "tcp"
  to_port           = var.webserver_port
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.webserver_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.webserver_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.webserver_sg.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Define security group to allow inbound traffic to lb
resource "aws_security_group" "lb_webserver" {
  name        = "lb-webserver-sg"
  description = "allow inbound traffic to lb for webservers"
}

resource "aws_vpc_security_group_ingress_rule" "allow_traffic_to_lb" {
  security_group_id = aws_security_group.lb_webserver.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = var.webserver_port
  ip_protocol       = "tcp"
  to_port           = var.webserver_port
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4_lb" {
  security_group_id = aws_security_group.lb_webserver.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


# Auto scaling group
####################################

# Define launch template for web servers of auto scaling group
resource "aws_launch_template" "webserver_asg_template" {
  name_prefix            = var.webserver_template_name_prefix
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.Webserver_instance_type
  vpc_security_group_ids = [aws_security_group.webserver_sg.id]
  user_data = base64encode(<<-EOF
    #!/bin/bash

    # Install nginx
    apt-get update && sudo apt-get install -y nginx

    # Customize index.html and listening port
    echo "<h1>Message from host: $(hostname)</h1>" > /var/www/html/index.html
    echo "<h1>Succesfully deployed web server on AWS !</h1>" >> /var/www/html/index.html
    sed -i 's/listen 80/listen ${var.webserver_port}/' /etc/nginx/sites-enabled/default

    # restart nginx
    systemctl restart nginx
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      server_type = "web"
      Name        = "Web server"
    }
  }
}

# Creates auto scaling group
resource "aws_autoscaling_group" "webserver_asg" {
  min_size            = 2
  desired_capacity    = 3
  max_size            = 6
  name_prefix         = var.webserver_asg_name_prefix
  vpc_zone_identifier = data.aws_subnets.default.ids
  health_check_type   = "ELB"
  target_group_arns   = [aws_lb_target_group.webserver.arn]


  launch_template {
    id      = aws_launch_template.webserver_asg_template.id
    version = aws_launch_template.webserver_asg_template.latest_version
  }

  # tag {
  #   key = "Name"
  #   value = "Web Server"
  #   propagate_at_launch = true
  # }
}

# Load balancer
####################################

# Define lb target group
resource "aws_lb_target_group" "webserver" {
  name        = "ASG-webserver-pool"
  port        = 8000
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = data.aws_vpc.default.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Define application load balancer
resource "aws_lb" "webserver_lb" {
  name               = var.webserver_lb_name
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.lb_webserver.id]

  tags = {
    Name = "LB webserver"
  }
}

# Define listener 
resource "aws_lb_listener" "webserver_lb" {
  load_balancer_arn = aws_lb.webserver_lb.arn
  port              = "8000"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      message_body = "<h1> ERREUR: Page Non Trouvée !</h1>"
      status_code  = 404
    }
  }
}

# Addd listener rule
resource "aws_lb_listener_rule" "webserver_lb" {
  listener_arn = aws_lb_listener.webserver_lb.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["/"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webserver.arn
  }
}

