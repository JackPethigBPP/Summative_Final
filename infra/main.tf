
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
  count                = var.enable_rds ? 1 : 0
  source               = "./modules/rds"
  
  project_name         = var.project_name
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  sg_ecs_id            = aws_security_group.app.id
}

resource "aws_security_group" "rds" {
  name   = "${var.project_name}-rds-sg"
  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group_rule" "rds_from_ec2" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.app.id
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

# App security group: allow 80 only from ALB SG
resource "aws_security_group" "app" {
  name   = "${var.project_name}-app-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [module.alb.alb_sg_id] # only ALB SG allowed
  }

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["90.200.141.239/32"]
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

resource "aws_ssm_parameter" "database_url" {
  count = var.enable_rds ? 1 : 0

  name  = "/${var.project_name}/DATABASE_URL"
  type  = "SecureString"
  value = "postgresql://${var.db_username}:${var.db_password}@${module.rds[0].endpoint}:5432/${var.db_name}"
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

    # Allow ec2-user to run docker (harmless for root scripts)
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

    # --- Port mapping defaults ---
    # Host port = ALB / instance port (default 80)
    HOST_PORT="80"

    # Container port = Flask/Gunicorn internal port (default 5000)
    CONTAINER_PORT="5000"

    echo "Using HOST_PORT=$${HOST_PORT} -> CONTAINER_PORT=$${CONTAINER_PORT}"

    aws ecr get-login-password --region "$REGION" | \
      docker login --username AWS --password-stdin "$REGISTRY"

    docker pull "$IMAGE"

    # ----------------------------
    # Read DATABASE_URL from SSM
    # ----------------------------
    DATABASE_URL="$(aws ssm get-parameter \
      --name "/${var.project_name}/DATABASE_URL" \
      --with-decryption \
      --region "$REGION" \
      --query 'Parameter.Value' \
      --output text || true)"

    if [ -z "$DATABASE_URL" ] || [ "$DATABASE_URL" = "None" ]; then
      echo "WARNING: SSM /${var.project_name}/DATABASE_URL empty or missing" >&2
    fi

    # ----------------------------
    # Run application container
    # ----------------------------
    docker rm -f cafe-app >/dev/null 2>&1 || true

    # Build env flags (only include DATABASE_URL if present)
    ENV_ARGS="-e PORT=$${CONTAINER_PORT} -e FLASK_ENV=production -e FLASK_DEBUG=0"
    if [ -n "$DATABASE_URL" ] && [ "$DATABASE_URL" != "None" ]; then
      ENV_ARGS="$ENV_ARGS -e DATABASE_URL=$DATABASE_URL"
    fi

    docker run -d --name cafe-app \
      --restart unless-stopped \
      -p $${HOST_PORT}:$${CONTAINER_PORT} \
      $${ENV_ARGS} \
      "$IMAGE"

    # ----------------------------
    # Verify container health
    # ----------------------------
    sleep 3
    docker ps --filter "name=cafe-app" --format "{{.Names}}" | grep -q cafe-app

    # Health check must hit HOST port
    curl -fsS "http://localhost:$${HOST_PORT}/healthz"

  EOT
}


# Launch template (attach LabInstanceProfile -> LabRole)
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux2.id
  instance_type = "t3.micro"
  #key_name      = "labsuser"
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
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
  health_check_type   = "ELB"
  health_check_grace_period = 300
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
  
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 180
    }
    triggers = ["launch_template"]
  }

}

resource "aws_autoscaling_attachment" "app_to_tg" {
  autoscaling_group_name = aws_autoscaling_group.app.name
  lb_target_group_arn    = module.alb.target_group_arn
}

