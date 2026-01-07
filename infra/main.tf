
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# VPC, subnets, SGs
module "vpc" {
  source               = "./modules/vpc"
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# ECR repo for app images
module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
}

# RDS PostgreSQL
module "rds" {
  source               = "./modules/rds"
  project_name         = var.project_name
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  db_name              = var.db_name
  db_username          = var.db_username
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  sg_ecs_id            = aws_security_group.app.id
}

# Application Load Balancer
module "alb" {
  source            = "./modules/alb"
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  container_port    = var.container_port
}

########################################
# EC2 App Tier (Launch Template + ASG) #
########################################

# App security group: allow 5000 only from ALB SG
resource "aws_security_group" "app" {
  name   = "${var.project_name}-app-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [module.alb.alb_sg_id] # only ALB SG allowed
  }

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["80.195.236.60/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-app-sg" }
}

# Amazon Linux 2 AMI
data "aws_ami" "amazon_linux2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# User data: install Docker, login to ECR, pull image, run container

locals {
  app_user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail

    # ----------------------------
    # Install Docker
    # ----------------------------
    yum -y update
    amazon-linux-extras install docker -y || yum install -y docker
    systemctl enable docker
    systemctl start docker

    # Ensure ec2-user can use docker (not strictly required for root scripts)
    usermod -aG docker ec2-user || true

    # ----------------------------
    # Install AWS CLI
    # ----------------------------
    yum install -y awscli

    # ----------------------------
    # ECR login + image pull
    # ----------------------------
    REGION="${var.region}"

    ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
    REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
    IMAGE="${module.ecr.repository_url}:${var.image_tag}"

    aws ecr get-login-password --region "$REGION" | \
      docker login --username AWS --password-stdin "$REGISTRY"

    docker pull "$IMAGE"

    # ----------------------------
    # Read DATABASE_URL from SSM
    # ----------------------------
    DB_URL="$(aws ssm get-parameter \
      --name "/${var.project_name}/DATABASE_URL" \
      --with-decryption \
      --region "$REGION" \
      --query 'Parameter.Value' \
      --output text || true)"

    if [ -z "$DB_URL" ] || [ "$DB_URL" = "None" ]; then
      echo "WARNING: SSM /${var.project_name}/DATABASE_URL empty or missing" >&2
    fi

    # ----------------------------
    # Run application container
    # ----------------------------
    docker rm -f cafe-app || true

    docker run -d \
      --name cafe-app \
      -p 5000:5000 \
      -e DATABASE_URL="$DB_URL" \
      -e FLASK_ENV=production \
      -e FLASK_DEBUG=0 \
      "$IMAGE"
  EOT
}

# Launch template (attach LabInstanceProfile -> LabRole)
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux2.id
  instance_type = "t3.micro"
  #key_name      = "labsuser"
  iam_instance_profile {
    name = "LabInstanceProfile" # pre-created in learner lab; attaches LabRole
  }
  user_data = base64encode(local.app_user_data)
  network_interfaces {
    security_groups             = [aws_security_group.app.id]
    associate_public_ip_address = true
  }
  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-app" }
  }
}

# Auto Scaling Group (1 instance)
resource "aws_autoscaling_group" "app" {
  name_prefix         = "${var.project_name}-asg-"
  max_size            = 1
  min_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = module.vpc.public_subnet_ids
  health_check_type   = "EC2"
  wait_for_capacity_timeout = "10m" 

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_attachment" "app_to_tg" {
  autoscaling_group_name = aws_autoscaling_group.app.name
  lb_target_group_arn    = module.alb.target_group_arn
}

