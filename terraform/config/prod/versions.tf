terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

}

provider "aws" {
  region  = "us-east-1"

  default_tags {
    tags = {
      Environment = "production"
      Project     = "asap-pdf"
      ManagedBy   = "terraform"
    }
  }
}
