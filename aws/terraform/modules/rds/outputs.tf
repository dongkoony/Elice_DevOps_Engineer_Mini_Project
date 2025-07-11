output "database_endpoints" {
  description = "생성된 데이터베이스 엔드포인트 정보"
  value = {
    for k, v in aws_db_instance.microservice_dbs : k => {
      endpoint = v.endpoint
      port     = v.port
      database = v.db_name
    }
  }
}

output "database_secret_arns" {
  description = "데이터베이스 비밀번호 Secrets Manager ARN 목록"
  value = {
    for k, v in aws_secretsmanager_secret.db_passwords : k => v.arn
  }
}

output "rds_kms_key_arn" {
  description = "RDS 암호화 KMS 키 ARN"
  value       = aws_kms_key.rds.arn
} 