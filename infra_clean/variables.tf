variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "project_name" {
  type    = string
  default = "cafe-app"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "container_port" {
  type    = number
  default = 5000
}

variable "image_tag" {
  type    = string
  default = "latest"
}

# Optional: if you want to inject a DB URL directly (simplest for now)
variable "database_url" {
  type    = string
  default = ""
  sensitive = true
}