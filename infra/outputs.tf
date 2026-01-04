
output "alb_dns" { value = module.alb.dns_name }
output "ecr_repo_url" { value = module.ecr.repository_url }
output "ecs_cluster" { value = module.ecs.cluster_name }
output "ecs_service" { value = module.ecs.service_name }
output "rds_endpoint" { value = module.rds.endpoint }
output "github_oidc_role_arn" { value = module.iam_oidc.role_arn }
