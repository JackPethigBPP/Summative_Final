
variable "project_name" { type = string }
variable "region" { type = string }
variable "vpc_cidr" { type = string }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "db_name" { type = string }
variable "db_username" { type = string }
variable "db_instance_class" { type = string }
variable "db_allocated_storage" { type = number }
variable "desired_count" { type = number }
variable "image_tag" {
  type    = string
  default = "latest"
}
variable "container_port" {
  description = "Port exposed by the application container"
  type = number
  default = 5000
}

