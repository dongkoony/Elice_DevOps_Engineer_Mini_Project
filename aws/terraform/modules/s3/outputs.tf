output "bucket_names" {
  description = "생성된 S3 버킷 이름 목록"
  value = {
    for k, v in aws_s3_bucket.buckets : k => v.bucket
  }
}

output "bucket_arns" {
  description = "생성된 S3 버킷 ARN 목록"
  value = {
    for k, v in aws_s3_bucket.buckets : k => v.arn
  }
}

output "bucket_domain_names" {
  description = "생성된 S3 버킷 도메인 이름 목록"
  value = {
    for k, v in aws_s3_bucket.buckets : k => v.bucket_domain_name
  }
} 