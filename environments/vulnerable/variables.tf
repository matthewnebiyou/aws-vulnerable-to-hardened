variable "aws_region" {
  description = "AWS region to deploy into: US East 1"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix used for tagging resources"
  type        = string
  default     = "aws-vuln-to-hard"
}

variable "my_ip" {
  description = "Public IP in CIDR form (e.g. 203.0.113.5/32). Not used to restrict anything here, since this environment is intentionally open."
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}
