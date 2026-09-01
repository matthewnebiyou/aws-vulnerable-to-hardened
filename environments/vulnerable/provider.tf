
# AWS Provider
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region_name
}

# Create a VPC
#resource "aws_vpc" "example" {
#  cidr_block = "10.0.0.0/16"
#}
