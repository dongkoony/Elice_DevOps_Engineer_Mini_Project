#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 환경별 정책 생성 함수
create_dev_policy() {
    echo '{"rules":[{"rulePriority":1,"description":"Keep last 5 tagged images","selection":{"tagStatus":"tagged","tagPrefixList":["dev-"],"countType":"imageCountMoreThan","countNumber":5},"action":{"type":"expire"}},{"rulePriority":2,"description":"Delete images older than 7 days","selection":{"tagStatus":"any","countType":"sinceImagePushed","countUnit":"days","countNumber":7},"action":{"type":"expire"}}]}'
}

create_stg_policy() {
    echo '{"rules":[{"rulePriority":1,"description":"Keep last 10 tagged images","selection":{"tagStatus":"tagged","tagPrefixList":["stg-"],"countType":"imageCountMoreThan","countNumber":10},"action":{"type":"expire"}},{"rulePriority":2,"description":"Delete images older than 14 days","selection":{"tagStatus":"any","countType":"sinceImagePushed","countUnit":"days","countNumber":14},"action":{"type":"expire"}}]}'
}

create_prod_policy() {
    echo '{"rules":[{"rulePriority":1,"description":"Keep last 20 tagged images","selection":{"tagStatus":"tagged","tagPrefixList":["prod-"],"countType":"imageCountMoreThan","countNumber":20},"action":{"type":"expire"}},{"rulePriority":2,"description":"Delete untagged images older than 1 day","selection":{"tagStatus":"untagged","countType":"sinceImagePushed","countUnit":"days","countNumber":1},"action":{"type":"expire"}},{"rulePriority":3,"description":"Delete any images older than 90 days","selection":{"tagStatus":"any","countType":"sinceImagePushed","countUnit":"days","countNumber":90},"action":{"type":"expire"}}]}'
}

# 환경별 리포지토리 처리
process_environment() {
    local env=$1
    local policy_func="create_${env}_policy"
    local policy_json=$($policy_func)
    
    log_info "Processing $env environment..."
    
    # 환경별 리포지토리 목록 가져오기
    local repos=$(aws ecr describe-repositories \
        --query "repositories[?contains(repositoryName, 'elice-devops-${env}-')].repositoryName" \
        --output text \
        --region ap-northeast-2)
    
    if [ -z "$repos" ]; then
        log_warning "No repositories found for environment: $env"
        return 0
    fi
    
    local success_count=0
    local failed_count=0
    
    for repo in $repos; do
        log_info "Applying policy to $repo..."
        
        if aws ecr put-lifecycle-policy \
            --repository-name "$repo" \
            --lifecycle-policy-text "$policy_json" \
            --region ap-northeast-2 > /dev/null 2>&1; then
            log_success "✓ $repo"
            ((success_count++))
        else
            log_error "✗ $repo"
            ((failed_count++))
        fi
        
        # 짧은 딜레이 (API 제한 방지)
        sleep 0.5
    done
    
    log_info "$env environment: $success_count success, $failed_count failed"
    return $failed_count
}

# 메인 함수
main() {
    echo "=================================="
    echo "ECR Lifecycle Policy Bulk Apply"
    echo "=================================="
    echo ""
    
    local total_failed=0
    
    # 각 환경별 처리
    for env in dev stg prod; do
        process_environment "$env"
        total_failed=$((total_failed + $?))
        echo ""
    done
    
    echo "=================================="
    if [ $total_failed -eq 0 ]; then
        log_success "All policies applied successfully!"
    else
        log_error "Some policies failed to apply. Total failures: $total_failed"
    fi
    echo "=================================="
}

# 스크립트 실행
main "$@" 