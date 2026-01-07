data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  ecr_repo   = aws_ecr_repository.app.repository_url
  image      = "${local.ecr_repo}:${var.image_tag}"
}

# -------------------------
# VPC (public subnets only)
# -------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.project_name}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.20.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-b" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# -------------------------
# ECR Repository
# -------------------------
resource "aws_ecr_repository" "app" {
  name = var.project_name
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = { Name = "${var.project_name}-ecr" }
}

# -------------------------
# Security Groups
# -------------------------
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB SG"
  vpc_id      = aws_vpc.main.id

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

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "EC2 SG"
  vpc_id      = aws_vpc.main.id

  # Allow ALB -> EC2 on container port (THIS is the classic 502 fix)
  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Optional: SSH from your IP (leave closed by default)
  # ingress {
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["YOUR_IP/32"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------
# Load Balancer + Target Group
# -------------------------
resource "aws_lb" "app" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/healthz"
    matcher             = "200"
    interval            = 20
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# -------------------------
# IAM for EC2 to pull ECR
# -------------------------
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.project_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# Enough for pulling from ECR
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# -------------------------
# AMI (Amazon Linux 2023)
# -------------------------
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# -------------------------
# User data (runs Docker)
# -------------------------
locals {
  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail

    exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
    echo "=== user-data start: $(date -Is) ==="

    dnf -y update
    dnf -y install docker awscli
    systemctl enable docker
    systemctl start docker

    REGION="${var.aws_region}"
    ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
    REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
    IMAGE="${local.image}"

    echo "Logging into ECR: $REGISTRY"
    aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"

    echo "Pulling image: $IMAGE"
    docker pull "$IMAGE"

    docker rm -f cafe-app || true

    DB_URL="${var.database_url}"

    echo "Starting container..."
    docker run -d \
    --restart unless-stopped \
    --name cafe-app \
    -p ${var.container_port}:${var.container_port} \
    -e DATABASE_URL="$DB_URL" \
    "$IMAGE"

    echo "Waiting for local health check..."
    for i in {1..30}; do
    if curl -fsS "http://localhost:${var.container_port}/healthz" >/dev/null; then
        echo "Health check OK"
        break
    fi
    sleep 2
    done

    curl -v "http://localhost:${var.container_port}/healthz" || (echo "ERROR: app not healthy locally" && exit 1)

    echo "=== user-data complete: $(date -Is) ==="
    EOT
}

# -------------------------
# Launch Template + ASG
# -------------------------
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = base64encode(local.user_data)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-ec2"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name                      = "${var.project_name}-asg"
  max_size                  = 1
  min_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
}