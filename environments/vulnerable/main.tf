# VULNERABLE-TO-HARDENED BASELINE ENVIRONMENT
#
# This configuration intentionally contains security misconfigurations


## AWS Provider
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.62.0"
    }
  }
}

# Configure the AWS Provider using the region_name variable defind in the variables file
provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

## Networking setup

# Creating a VPC (virtual private cloud)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# Creating gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true # instance gets a public IP automatically

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


########################


# VULN 1: Security group open to the world
# SSH (port 22) and HTTP (port 80) reachable from 0.0.0.0/0
# Maps to CIS 5.2

resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "An intentionally overly permissive security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}


#########################


# VULN 2: IAM role with AdministratorAccess
# Attached to the EC2 instance profile.
# Maps to CIS 1.16

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_admin" {
  role       = aws_iam_role.ec2_role.name
  # Providing admin access
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}


###########################


# VULN 3: IAM user with a long-lived access key
# Simulates a "leaked credential" scenario.
# Maps to CIS 1.4, 1.12

resource "aws_iam_user" "app_user" {
  name = "${var.project_name}-app-user"

  tags = {
    Name = "${var.project_name}-app-user"
  }
}


# Creating the static, long-lived key without any sort of rotation policy
resource "aws_iam_access_key" "app_user_key" {
  user = aws_iam_user.app_user.name
}

resource "aws_iam_user_policy_attachment" "app_user_admin" {
  user       = aws_iam_user.app_user.name
  # Providing admin access to user with static, long-lived key
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}


############################


# VULN 4: S3 bucket with public access and no encryption.
# Maps to CIS 2.1.1, 2.1.2

resource "aws_s3_bucket" "data" {
  bucket = "${var.project_name}-data-${data.aws_caller_identity.current.account_id}"
  tags = {
    Name = "${var.project_name}-data-bucket"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  # The following creates highly permissive/vulnerable settings for the s3 bucket
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "data" {
  depends_on = [
    aws_s3_bucket_ownership_controls.data,
    aws_s3_bucket_public_access_block.data
  ]
  bucket = aws_s3_bucket.data.id
  acl    = "public-read" # VULNERABLE
}

# No aws_s3_bucket_server_side_encryption_configuration resource here. Encryption intentionally omitted for this baseline.


############################


# FINDING 5: Unencrypted EBS volume on the instance
# Maps to CIS 2.2.1

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # Ensuring no encruption in the volume the instance uses
  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = false
  }

  tags = {
    Name = "${var.project_name}-web"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  # Filtering to anything based on x86_64 architecture as that is compatible with t3-micro EC2 instance
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
