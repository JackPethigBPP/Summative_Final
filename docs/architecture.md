
# Cafe App — AWS ECS Fargate Architecture (us-east-1)

```mermaid
flowchart LR
  U[User Browser] -->|HTTP 80| ALB[Application Load Balancer]
  ALB --> ECS[ECS Fargate Service]
  ECS -->|SQL 5432| RDS[(RDS PostgreSQL)]

  subgraph AWS
    ALB
    ECS
    RDS
    ECR[Elastic Container Registry]
    CW[CloudWatch Logs/Dashboard]
    SSM[SSM Parameter: /cafe/DATABASE_URL]
  end

  GH[GitHub Actions] -->|OIDC AssumeRole| IAM[IAM Role]
  GH -->|Docker Push| ECR
  GH -->|Terraform Apply| AWS
```

**Notes**
- ECS tasks run in **public subnets** (assign public IP), ALB also in public subnets; RDS in **private subnets**.
- Security groups: ALB → ECS (port 5000), ECS → RDS (5432).
- The app reads `DATABASE_URL` injected from **SSM SecureString**.
- Logs to **CloudWatch**; you can add a dashboard + alarms.
- CI/CD uses **GitHub OIDC** to assume an AWS role (no static secrets).
