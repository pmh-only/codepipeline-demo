resource "terraform_data" "taskdef" {
  triggers_replace = [
    timestamp()
  ]

  provisioner "local-exec" {
    command = "aws ecs describe-task-definition --task-definition ${module.ecs_service.task_definition_family} --query 'taskDefinition' > ${path.module}/tmp/taskdef.original.json"
  }
}

data "local_file" "taskdef" {
  filename = "${path.module}/tmp/taskdef.original.json"

  depends_on = [
    terraform_data.taskdef
  ]
}

resource "local_file" "taskdef" {
  content = replace(
    jsonencode(merge(
      jsondecode(data.local_file.taskdef.content),
      {
        
      }
    )),
    "/${aws_ecr_repository.repo.repository_url}:[^\"]+/",
    "<IMAGE1_NAME>"
  )
  filename = "${path.module}/src/taskdef.json"
}
