terraform {
  backend "s3" {
    bucket         = "${var.project_name}-${var.environment}-tfstate"
    key            = "${var.project_name}.tfstate"
    region         = var.aws_region
    dynamodb_table = "${var.environment}.tfstate"
  }
}
module "backend" {
  source = "github.com/codeforamerica/tofu-modules-aws-backend?ref=1.1.1"

  project     = var.project_name
  environment = var.environment
}

module "asap_pdf" {
  source = "../../modules/asap_pdf"

  domain_name = "demo.codeforamerica.ai"
  project_name = var.project_name
  environment  = var.environment
  # todo change this to test.
  rails_environment = "production"
  backend_kms_key = module.backend.kms_key

  vpc_cidr = "10.0.0.0/16"
  public_subnet_cidrs =  ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  bastion_key_pair_name = "asap-migration-staging"
}

module "cloudfront" {
  source = "../../modules/cloudfront"

  destination = "https://demo.codeforamerica.ai"
  source_domain = var.redirect_domain
  logging_bucket = module.asap_pdf.logging_bucket
}