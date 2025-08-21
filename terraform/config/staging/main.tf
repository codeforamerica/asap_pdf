terraform {
  backend "s3" {
    bucket         = "asap-pdf-staging-tfstate"
    key            = "asap-pdf.tfstate"
    region         = "us-east-1"
    dynamodb_table = "staging.tfstate"
  }
}
module "backend" {
  source = "github.com/codeforamerica/tofu-modules-aws-backend?ref=1.1.1"

  project     = "asap-pdf"
  environment = "staging"
}

module "asap_pdf" {
  source = "../../modules/asap_pdf"

  # Github actions deployment-related variables.
  # Should match the branch and environment name setup in Github settings.
  github_branch = "dev"
  github_environment = "staging"

  # AWS Environment related variables.
  domain_name = "staging.ada.codeforamerica.ai"
  project_name = "asap-pdf"
  environment  = "staging"
  # todo change this to test.
  rails_environment = "test"
  backend_kms_key = module.backend.kms_key
  vpc_cidr = "10.0.0.0/16"
  public_subnet_cidrs =  ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  single_nat_gateway = true
  rds_multi_az = false
}