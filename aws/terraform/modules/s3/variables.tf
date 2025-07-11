variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "buckets" {
  description = "생성할 S3 버킷 목록"
  type = map(object({
    description         = string
    versioning_enabled  = bool
  }))
  default = {
    app-data = {
      description         = "애플리케이션 데이터 저장"
      versioning_enabled  = true
    }
    backups = {
      description         = "백업 데이터 저장"
      versioning_enabled  = true
    }
    logs = {
      description         = "로그 데이터 저장"
      versioning_enabled  = false
    }
  }
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