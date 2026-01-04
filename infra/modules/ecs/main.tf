
variable "project_name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "repository_url" { type = string }
variable "image_tag" { type = string }
variable "container_port" { type = number }
variable "desired_count" { type = number }
variable "alb_target_group_arn" { type = string }
variable "database_url_ssm_arn" { type = string }

# ECS SG allows traffic from ALB SG (passed indirectly via target group)
resource "aws_security_group" "ecs" {
  name   = "${var.project_name}-ecs-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Target group forwards traffic; SG still needs to allow
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-ecs-sg" }
}

# IAM roles
resource "aws_iam_role" "task_execution" {
  name               = "${var.project_name}-task-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Effect = "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_exec_ecr" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow reading SecureString from SSM
resource "aws_iam_policy" "ssm_read" {
  name   = "${var.project_name}-ssm-read"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["ssm:GetParameters", "ssm:GetParameter"],
      Resource = var.database_url_ssm_arn
    }]
  })
}
resource "aws_iam_role_policy_attachment" "task_exec_ssm" {
  role       = aws_iam_role.task_execution.name
  policy_arn = aws_iam_policy.ssm_read.arn
}

# Task role (for app if it uses AWS SDK later)
resource "aws_iam_role" "task" {
  name               = "${var.project_name}-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Effect = "Allow"
    }]
  })
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"
}

locals {
  image = "${var.repository_url}:${var.image_tag}"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-container",
      image     = local.image,
      essential = true,
      portMappings = [{ containerPort = var.container_port, protocol = "tcp" }],
      environment = [
        { name = "FLASK_ENV", value = "production" },
        { name = "FLASK_DEBUG", value = "0" }
      ],
      secrets = [
        { name = "DATABASE_URL", valueFrom = var.database_url_ssm_arn }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name,
          awslogs-region        = var.region,
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.public_subnet_ids
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "${var.project_name}-container"
    container_port   = var.container_port
  }

  lifecycle { ignore_changes = [task_definition] } # allow new deploys
}

output "cluster_name" { value = aws_ecs_cluster.this.name }
output "service_name" { value = aws_ecs_service.app.name }
output "ecs_sg_id" { value = aws_security_group.ecs.id }
