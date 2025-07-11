variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "databases" {
  description = "생성할 데이터베이스 목록"
  type = map(object({
    database_name = string
    username      = string
  }))
  default = {
    user = {
      database_name = "user_db"
      username      = "user_admin"
    }
    auth = {
      database_name = "auth_db"
      username      = "auth_admin"
    }
    product = {
      database_name = "product_db"
      username      = "product_admin"
    }
    order = {
      database_name = "order_db"
      username      = "order_admin"
    }
    payment = {
      database_name = "payment_db"
      username      = "payment_admin"
    }
  }
}

variable "postgres_version" {
  description = "PostgreSQL 버전"
  type        = string
  default     = "15.13"
}

variable "db_instance_class" {
  description = "DB 인스턴스 클래스"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "기본 스토리지 크기(GB)"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "최대 스토리지 크기(GB)"
  type        = number
  default     = 100
}

variable "rds_security_group_id" {
  description = "RDS 보안그룹 ID"
  type        = string
}

variable "database_subnet_group_name" {
  description = "데이터베이스 서브넷 그룹 이름"
  type        = string
}

variable "backup_retention_period" {
  description = "백업 보관 기간(일)"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "백업 시간(UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "유지보수 시간(UTC)"
  type        = string
  default     = "Sun:04:00-Sun:05:00"
}

variable "multi_az" {
  description = "다중 AZ 배포 사용"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "최종 스냅샷 건너뛰기"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default = {
    Project     = "elice-devops"
    Environment = "production"
    ManagedBy   = "terraform"
  }
} 