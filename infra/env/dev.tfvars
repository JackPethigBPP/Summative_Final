
project_name         = "cafe"
region               = "eu-north-1"
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

enable_rds           = true
db_name              = "cafedb" 
db_username          = "cafedbuser"
db_password          = "change-me-securely"
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20

container_port = 5000
desired_count  = 1

# This will be set by the pipeline; for local apply you can set "latest"
image_tag = "latest"

# Optional: set to "youruser/yourrepo" to create OIDC role
# github_repo       = "<your-username>/<your-repo>"
