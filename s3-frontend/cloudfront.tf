module "cloudfront" {
  source = "terraform-aws-modules/cloudfront/aws"

  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = false
  http_version = "http2and3"

  default_root_object = "index.html"

  logging_config = {
    bucket = module.log_bucket.s3_bucket_bucket_domain_name
    include_cookies = true
  }
  
  create_origin_access_control = true
  origin_access_control = {
    s3_bucket = {
      description      = "CloudFront access to S3"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  origin = {
    frontend = {
      domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
      origin_access_control = "s3_bucket"
    }
  }

  default_cache_behavior = {
    target_origin_id           = "frontend"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true

    use_forwarded_values = false
    cache_policy_name            = "Managed-CachingOptimized"
  }

  custom_error_response = [{
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }]
}
