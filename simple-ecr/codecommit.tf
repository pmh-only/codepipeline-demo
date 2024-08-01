resource "aws_codecommit_repository" "repo" {
  repository_name = "${var.project_name}-repo"
  default_branch = "main"
}
