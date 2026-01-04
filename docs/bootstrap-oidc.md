
# Bootstrap: GitHub OIDC for AWS Learner Lab

Because Terraform itself creates the GitHub OIDC role, you need **one-time credentials** to run `terraform apply` the first time.

Two safe options:

## Option A — Run Terraform locally with Learner Lab credentials
1. In the AWS Academy Learner Lab, click **AWS Details** → **Show Credentials**.
2. Run locally:
   ```bash
   cd infra
   terraform init
   terraform apply -var-file=env/dev.tfvars
   ```
3. Copy the output `github_oidc_role_arn`.
4. In your GitHub repository, update the workflow to assume that role (see `.github/workflows/cd.yml`).

## Option B — Temporary secrets in GitHub (first run only)
1. Add `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_REGION` to repo **Secrets**.
2. Run the workflow once to create the OIDC role.
3. Remove the secrets and switch the workflow to OIDC.

Discuss the **trade-offs** in your presentation: OIDC (short-lived, least-privilege) vs secrets (riskier).
