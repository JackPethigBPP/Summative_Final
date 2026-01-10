
output "alb_dns" { value = module.alb.dns_name }
output "ecr_repo_url" { value = module.ecr.repository_url }
output "rds_endpoint" { value = try(module.rds.endpoint, null) }
output "target_group_arn" { value = module.alb.target_group_arn }