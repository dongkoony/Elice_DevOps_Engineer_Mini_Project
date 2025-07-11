# RDS 서브넷 그룹 (이미 VPC 모듈에서 생성되어 전달받음)
# 여기서는 받은 서브넷 그룹 이름을 사용

# 각 마이크로서비스별 PostgreSQL 데이터베이스 생성
resource "aws_db_instance" "microservice_dbs" {
  for_each = var.databases

  identifier     = "${var.project_name}-${each.key}-db"
  engine         = "postgres"
  engine_version = var.postgres_version
  instance_class = var.db_instance_class
  
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type         = "gp3"
  storage_encrypted    = true
  kms_key_id          = aws_kms_key.rds.arn

  db_name  = each.value.database_name
  username = each.value.username
  password = random_password.db_passwords[each.key].result

  vpc_security_group_ids = [var.rds_security_group_id]
  db_subnet_group_name   = var.database_subnet_group_name

  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window

  multi_az               = var.multi_az
  publicly_accessible    = false
  auto_minor_version_upgrade = true

  performance_insights_enabled = true
  monitoring_interval         = 60
  monitoring_role_arn         = aws_iam_role.rds_monitoring.arn

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  copy_tags_to_snapshot = true
  skip_final_snapshot   = var.skip_final_snapshot
  final_snapshot_identifier = "${var.project_name}-${each.key}-final-snapshot"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${each.key}-db"
    Type = "PostgreSQL 데이터베이스"
    Service = each.key
  })
}

# 데이터베이스 비밀번호 생성 (RDS 호환 문자만 사용)
resource "random_password" "db_passwords" {
  for_each = var.databases

  length           = 32
  special          = true
  override_special = "!#$%&*+-=?^_`{|}~"  # RDS에서 허용하는 특수문자만 사용 (/, @, ", 공백 제외)
}

# Secrets Manager에 데이터베이스 비밀번호 저장
resource "aws_secretsmanager_secret" "db_passwords" {
  for_each = var.databases

  name = "${var.project_name}-${each.key}-db-password"
  description = "${each.key} 데이터베이스 비밀번호"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${each.key}-db-password"
    Type = "데이터베이스 비밀번호"
    Service = each.key
  })
}

# Secrets Manager에 비밀번호 저장
resource "aws_secretsmanager_secret_version" "db_passwords" {
  for_each = var.databases

  secret_id = aws_secretsmanager_secret.db_passwords[each.key].id
  secret_string = jsonencode({
    username = each.value.username
    password = random_password.db_passwords[each.key].result
    endpoint = aws_db_instance.microservice_dbs[each.key].endpoint
    port     = aws_db_instance.microservice_dbs[each.key].port
    database = each.value.database_name
  })
}

# RDS 암호화용 KMS 키
resource "aws_kms_key" "rds" {
  description             = "${var.project_name} RDS 암호화 키"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-rds-kms-key"
    Type = "RDS 암호화 키"
  })
}

# RDS KMS 키 별칭
resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# RDS 향상된 모니터링 역할
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-rds-monitoring-role"
    Type = "RDS 모니터링 역할"
  })
}

# RDS 모니터링 정책 연결
resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
} 