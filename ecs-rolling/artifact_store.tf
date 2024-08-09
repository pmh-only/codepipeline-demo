resource "aws_s3_bucket" "artifacts" {
  bucket_prefix = "${var.project_name}-artifacts"
  force_destroy = true
}
