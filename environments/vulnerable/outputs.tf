output "instance_public_ip" {
  description = "Public IP of the web instance"
  value       = aws_instance.web.public_ip
}

output "s3_bucket_name" {
  description = "Name of the public S3 bucket"
  value       = aws_s3_bucket.data.bucket
}

output "app_user_access_key_id" {
  description = "Access key ID for the simulated app user"
  value       = aws_iam_access_key.app_user_key.id
}

output "app_user_secret_access_key" {
  description = "Secret access key for the simulated user"
  value       = aws_iam_access_key.app_user_key.secret
  sensitive   = true
}
