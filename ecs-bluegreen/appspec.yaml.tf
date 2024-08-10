resource "local_file" "appspec" {
  content  = <<-EOF
    version: 0.0
    Resources:
      - TargetService:
          Type: AWS::ECS::Service
          Properties:
            TaskDefinition: <TASK_DEFINITION>
            LoadBalancerInfo: 
              ContainerName: "${var.project_name}-app"
              ContainerPort: 8080
  EOF
  filename = "${path.module}/src/appspec.yaml"
}
