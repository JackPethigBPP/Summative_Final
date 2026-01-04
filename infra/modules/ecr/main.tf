
variable "project_name" { type = string }
resource "aws_ecr_repository" "repo" {
  name                 = "${var.project_name}-repo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
  tags = { Name = "${var.project_name}-ecr" }
}
output "repository_url" { value = aws_ecr_repository.repo.repository_url }
