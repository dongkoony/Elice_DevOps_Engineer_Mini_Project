# VPC 정보
output "vpc_id" {
  description = "생성된 VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR 블록"
  value       = module.vpc.vpc_cidr_block
}

# EKS 클러스터 정보
output "eks_cluster_endpoint" {
  description = "EKS 클러스터 엔드포인트"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_id" {
  description = "EKS 클러스터 ID"
  value       = module.eks.cluster_id
}

output "eks_cluster_arn" {
  description = "EKS 클러스터 ARN"
  value       = module.eks.cluster_arn
}

output "eks_cluster_certificate_authority_data" {
  description = "EKS 클러스터 인증서 기관 데이터"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

# IAM 역할 정보
output "eks_cluster_role_arn" {
  description = "EKS 클러스터 IAM 역할 ARN"
  value       = module.iam_base.eks_cluster_role_arn
}

output "eks_nodes_role_arn" {
  description = "EKS 노드 그룹 IAM 역할 ARN"
  value       = module.iam_base.eks_nodes_role_arn
}

output "ebs_csi_driver_role_arn" {
  description = "EBS CSI 드라이버 IAM 역할 ARN"
  value       = module.iam_oidc.ebs_csi_driver_role_arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "AWS Load Balancer Controller IAM 역할 ARN"
  value       = module.iam_oidc.aws_load_balancer_controller_role_arn
}

# 보안 그룹 정보
output "alb_security_group_id" {
  description = "애플리케이션 로드밸런서 보안 그룹 ID"
  value       = module.security_groups.alb_security_group_id
}

output "eks_nodes_security_group_id" {
  description = "EKS 노드 보안 그룹 ID"
  value       = module.security_groups.eks_nodes_security_group_id
}

# RDS 데이터베이스 정보
output "database_endpoints" {
  description = "생성된 데이터베이스 엔드포인트 정보"
  value       = module.rds.database_endpoints
  sensitive   = true
}

output "database_secret_arns" {
  description = "데이터베이스 비밀번호 Secrets Manager ARN 목록"
  value       = module.rds.database_secret_arns
}

# S3 버킷 정보
output "s3_bucket_names" {
  description = "생성된 S3 버킷 이름 목록"
  value       = module.s3.bucket_names
}

output "s3_bucket_arns" {
  description = "생성된 S3 버킷 ARN 목록"
  value       = module.s3.bucket_arns
}

# ECR 리포지토리 정보
output "ecr_repository_urls" {
  description = "생성된 ECR 리포지토리 URL 목록"
  value = {
    for k, v in aws_ecr_repository.microservices : k => v.repository_url
  }
}

# 연결 정보
output "eks_cluster_connection_command" {
  description = "EKS 클러스터 연결 명령어"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_id}"
} 