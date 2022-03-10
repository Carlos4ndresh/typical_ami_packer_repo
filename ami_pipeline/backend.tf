terraform {
  backend "s3" {
    bucket         = "terraform-projects-state"
    key            = "demo/ami_packer_pipeline.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-state-lock-table"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>3.70"
    }
  }
}

provider "aws" {
  region = "us-west-2"
  default_tags {
    tags = {
      "Env"         = "dev",
      "Owner"       = "cherrera",
      "Provisioner" = "terraform",
      "Project"     = "Demo AMI Pipeline"
    }
  }
}

