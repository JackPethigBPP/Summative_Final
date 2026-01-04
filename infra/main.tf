
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
  source           = "./modules/rds"
  project_name     = var.project_name
  vpc_id           = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  db_name          = var.db_name
  db_username      = var.db_username
  db_instance_class = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  sg_ecs_id        = module.ecs.ecs_sg_id
}

# Application Load Balancer
module "alb" {
  source           = "./modules/alb"
  project_name     = var.project_name
  vpc_id           = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  container_port   = var.container_port
}

# ECS cluster and service
module "ecs" {
  source               = "./modules/ecs"
  project_name         = var.project_name
  vpc_id               = module.vpc.vpc_id
  public_subnet_ids    = module.vpc.public_subnet_ids
  repository_url       = module.ecr.repository_url
  image_tag            = var.image_tag
  container_port       = var.container_port
  desired_count        = var.desired_count
  alb_target_group_arn = module.alb.target_group_arn
  database_url_ssm_arn = module.rds.database_url_ssm_arn
}

# Optional GitHub OIDC role for Actions (created only if github_repo provided)
module "iam_oidc" {
  source      = "./modules/iam_oidc"
  project_name = var.project_name
  github_repo = var.github_repo
  count = var.github_repo == null ? 0 : 1
}
