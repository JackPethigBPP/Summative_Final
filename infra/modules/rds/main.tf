
variable "project_name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "db_name" { type = string }
variable "db_username" { type = string }
variable "db_password" { type = string }
variable "db_instance_class" { type = string }
variable "db_allocated_storage" { type = number }
variable "sg_ecs_id" { type = string }

resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnets-${substr(var.vpc_id,0,8)}" 
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${var.project_name}-db-subnets" }

  lifecycle {
    create_before_destroy = true # keep if you ever change VPC/subnets
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Managed by Terraform"
  vpc_id      = var.vpc_id
  ingress {
    description     = "Postgres from App"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.sg_ecs_id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-rds-sg" }

  lifecycle {
    ignore_changes = [ 
      description,
      tags,
      tags_all
     ]
  }
}

resource "aws_db_instance" "this" {
  identifier = "${var.project_name}-db-${substr(var.vpc_id,0,8)}"
  lifecycle {
    create_before_destroy = true
    ignore_changes = [password]
  }
  apply_immediately      = true
  engine                 = "postgres"
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false
  storage_encrypted      = true
  tags                   = { Name = "${var.project_name}-rds" }
}

output "endpoint" { value = aws_db_instance.this.address }
