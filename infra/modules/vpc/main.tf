
#######################################
# VPC across two AZs (public + private)
#######################################

# ---- Variables ----
variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  # Example: ["10.0.1.0/24", "10.0.2.0/24"]
  type = list(string)
}

variable "private_subnet_cidrs" {
  # Example: ["10.0.10.0/24", "10.0.11.0/24"]
  type = list(string)
}

# ---- Discover AZs that are 'available' in this region ----
data "aws_availability_zones" "available" {
  state = "available"
}

# We’ll map each CIDR to a distinct AZ by index.
# If you provide two public CIDRs and two private CIDRs, they will be assigned to AZ[0] and AZ[1] respectively.
locals {
  public_azs = {
    for idx, cidr in var.public_subnet_cidrs :
    cidr => data.aws_availability_zones.available.names[idx]
  }

  private_azs = {
    for idx, cidr in var.private_subnet_cidrs :
    cidr => data.aws_availability_zones.available.names[idx]
  }
}

# ---- VPC ----
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ---- Internet Gateway (for public subnets) ----
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ---- Public Subnets (explicit AZ assignment) ----
resource "aws_subnet" "public" {
  for_each                = local.public_azs
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.key
  availability_zone       = each.value
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${replace(each.key, "/", "-")}"
    Tier = "public"
  }
}

# Routing for public subnets → Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route" "public_inet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ---- Private Subnets (explicit AZ assignment) ----
# NOTE: Simple lab setup—no NAT gateways to reduce cost and complexity.
resource "aws_subnet" "private" {
  for_each          = local.private_azs
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.key
  availability_zone = each.value

  tags = {
    Name = "${var.project_name}-private-${replace(each.key, "/", "-")}"
    Tier = "private"
  }
}

# ---- Outputs ----
output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

