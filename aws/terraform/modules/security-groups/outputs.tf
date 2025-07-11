output "alb_security_group_id" {
  description = "애플리케이션 로드밸런서 보안 그룹 ID"
  value       = aws_security_group.alb.id
}

output "eks_cluster_security_group_id" {
  description = "EKS 클러스터 보안 그룹 ID"
  value       = aws_security_group.eks_cluster.id
}

output "eks_nodes_security_group_id" {
  description = "EKS 노드 그룹 보안 그룹 ID"
  value       = aws_security_group.eks_nodes.id
}

output "rds_security_group_id" {
  description = "RDS 데이터베이스 보안 그룹 ID"
  value       = aws_security_group.rds.id
}

output "efs_security_group_id" {
  description = "EFS 파일 시스템 보안 그룹 ID"
  value       = aws_security_group.efs.id
} 