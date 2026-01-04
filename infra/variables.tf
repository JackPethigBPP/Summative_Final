
variable "project_name" { type = string }
variable "region" { type = string }
variable "vpc_cidr" { type = string }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "db_name" { type = string }
variable "db_username" { type = string }
variable "db_instance_class" { type = string }
variable "db_allocated_storage" { type = number }
variable "container_port" { type = number }
variable "desired_count" { type = number }
variable "image_tag" { type = string }

# GitHub OIDC repo filter (e.g. "youruser/yourrepo")
variable "github_repo" { type = string, default = null }
