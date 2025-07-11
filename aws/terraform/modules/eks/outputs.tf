output "cluster_id" {
  description = "EKS 클러스터 ID"
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "EKS 클러스터 ARN"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "EKS 클러스터 엔드포인트"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "EKS 클러스터 보안 그룹 ID"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "EKS 클러스터 인증서 기관 데이터"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_version" {
  description = "EKS 클러스터 버전"
  value       = aws_eks_cluster.main.version
}

output "oidc_issuer_url" {
  description = "OIDC 발급자 URL"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "OIDC 프로바이더 ARN"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "node_group_arn" {
  description = "EKS 노드 그룹 ARN"
  value       = aws_eks_node_group.main.arn
}

output "node_group_status" {
  description = "EKS 노드 그룹 상태"
  value       = aws_eks_node_group.main.status
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch 로그 그룹 이름"
  value       = aws_cloudwatch_log_group.eks_cluster.name
}

output "kms_key_arn" {
  description = "EKS 암호화 KMS 키 ARN"
  value       = aws_kms_key.eks.arn
}

output "kms_key_id" {
  description = "EKS 암호화 KMS 키 ID"
  value       = aws_kms_key.eks.key_id
} 