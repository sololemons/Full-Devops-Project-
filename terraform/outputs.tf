output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "receipts_bucket_name" {
  description = "The S3 bucket for receipts"
  value       = aws_s3_bucket.receipts.id
}

output "iam_role_arn" {
  description = "IAM Role for the payments pod"
  value       = module.payments_s3_role.iam_role_arn
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS control plane"
  value       = module.eks.cluster_endpoint
}