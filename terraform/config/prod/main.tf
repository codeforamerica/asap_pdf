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
  # Github actions deployment-related variables.
  # Should match the branch and environment name setup in Github settings.
  github_branch = "main"
  github_environment = "prod"

  # AWS Environment related variables.
  domain_name = "ada.codeforamerica.ai"
  project_name = var.project_name
  environment  = var.environment
  rails_environment = "production"
  backend_kms_key = module.backend.kms_key
  vpc_cidr = "10.0.52.0/22"
  public_subnet_cidrs = ["10.0.52.0/26", "10.0.52.64/26", "10.0.52.128/26"]
  private_subnet_cidrs = ["10.0.54.0/26", "10.0.54.64/26", "10.0.54.128/26"]
}

# Optional, comment out to have no additional domains.
module "cloudfront" {
  source = "../../modules/cloudfront"

  destination = "https://ada.codeforamerica.ai"
  source_domain = var.redirect_domain
  logging_bucket = module.asap_pdf.logging_bucket
}