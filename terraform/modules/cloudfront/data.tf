data "aws_route53_zone" "source" {
  for_each = var.create_records ? toset(["this"]) : toset([])

  name = var.source_domain
}

data "aws_cloudfront_cache_policy" "endpoint" {
  name = "Managed-CachingOptimized"
}