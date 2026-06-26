data "aws_route53_zone" "domain" {
  name = var.domain_name
}

module "ses" {
  name =  "${var.project_name}-${var.environment}-ses"
  source = "github.com/cloudposse/terraform-aws-ses?ref=v0.25.2"
  domain = var.domain_name
  zone_id = data.aws_route53_zone.domain.id
  verify_domain = true
  verify_dkim = true
}