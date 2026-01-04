
variable "project_name" { type = string }
variable "github_repo" { type = string }

# Create OIDC provider for GitHub
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# Role that GitHub Actions can assume
resource "aws_iam_role" "github" {
  name = "${var.project_name}-github-oidc-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        },
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
        }
      }
    }]
  })
}

# Broad policy for Terraform apply in lab (simplify for demo; discuss least-privilege in reflection)
resource "aws_iam_policy" "github_permissions" {
  name   = "${var.project_name}-github-iac"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = "ecr:*", Resource = "*" },
      { Effect = "Allow", Action = ["ecs:*", "ec2:*", "elasticloadbalancing:*", "logs:*", "iam:PassRole", "rds:*", "ssm:*", "cloudwatch:*"], Resource = "*" },
      { Effect = "Allow", Action = ["sts:AssumeRole", "iam:CreateRole", "iam:AttachRolePolicy", "iam:CreatePolicy", "iam:PutRolePolicy"], Resource = "*" }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.github.name
  policy_arn = aws_iam_policy.github_permissions.arn
}

output "role_arn" { value = aws_iam_role.github.arn }
