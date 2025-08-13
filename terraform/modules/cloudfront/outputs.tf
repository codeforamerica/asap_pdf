output "certificate_validation_records" {
  description = "The DNS records required to validate the ACM certificate."
  value       = { for dvo in aws_acm_certificate.this.domain_validation_options : dvo.resource_record_name => dvo.resource_record_value }
}

output "cloudfront_dns" {
  description = "DNS information for the CloudFront distribution needed to create DNS records."
  value = {
    name : local.fqdn
    target : aws_cloudfront_distribution.this.domain_name
    zone_id : aws_cloudfront_distribution.this.hosted_zone_id
  }
}

output "url" {
  description = "The fully qualified URL for the redirect."
  value       = local.fqdn
}