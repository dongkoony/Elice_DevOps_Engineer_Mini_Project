# S3 버킷 생성
resource "aws_s3_bucket" "buckets" {
  for_each = var.buckets

  bucket = "${var.project_name}-${each.key}"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${each.key}"
    Type = each.value.description
  })
}

# S3 버킷 버전 관리
resource "aws_s3_bucket_versioning" "buckets" {
  for_each = var.buckets

  bucket = aws_s3_bucket.buckets[each.key].id
  versioning_configuration {
    status = each.value.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# S3 버킷 암호화
resource "aws_s3_bucket_server_side_encryption_configuration" "buckets" {
  for_each = var.buckets

  bucket = aws_s3_bucket.buckets[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 버킷 퍼블릭 액세스 차단
resource "aws_s3_bucket_public_access_block" "buckets" {
  for_each = var.buckets

  bucket = aws_s3_bucket.buckets[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 버킷 라이프사이클 정책
resource "aws_s3_bucket_lifecycle_configuration" "buckets" {
  for_each = var.buckets

  bucket = aws_s3_bucket.buckets[each.key].id

  rule {
    id     = "lifecycle_rule"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
} 