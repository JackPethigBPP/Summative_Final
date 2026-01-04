
# Terraform IaC — AWS ECS Fargate + ALB + RDS (us-east-1)

This stack provisions a simple production-like environment for the cafe Flask app:

- VPC (public subnets for ALB & ECS tasks, private subnets for RDS)
- Security groups (ALB → ECS → RDS)
- ECR repository
- ECS cluster, task definition, service (awsvpc with public IPs)
- Application Load Balancer (HTTP 80)
- RDS PostgreSQL (db.t3.micro by default)
- SSM Parameter (SecureString) storing `DATABASE_URL` for the app
- Optional IAM OIDC role for GitHub Actions to assume (recommended)

## Usage (local Terraform)

```bash
cd infra
terraform init
terraform apply -var-file=env/dev.tfvars
```

Outputs will show ALB URL to access the app.

## GitHub Actions — CD
The repository can be wired with `.github/workflows/cd.yml` to:
- Run tests
- Build & push image to ECR
- Assume IAM role via OIDC
- `terraform plan` / `apply` (using `TF_VAR_image_tag`)

See `docs/bootstrap-oidc.md` for first-time setup notes.

