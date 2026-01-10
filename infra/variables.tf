
variable "project_name" { type = string }
variable "region" { 
  type = string 
  default = "eu-north-1"
}

variable "vpc_cidr" { type = string }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }

variable "db_name" { 
  type = string 
  default = null 
}

variable "db_username" { 
  type = string 
  default = null
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = null
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "enable_rds" {
  type = bool
  description = "Whether to create the RDS instance"
  default = true
}

variable "desired_count" {
  type    = number
  default = 1
}
variable "image_tag" {
  type    = string
  default = "latest"
}
variable "container_port" {
  description = "Port exposed by the application container"
  type        = number
  default     = 80
}
