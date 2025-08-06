#!/bin/bash

# Elice DevOps Project - ECR Push Automation Script
# 마이크로서비스 Docker 이미지를 AWS ECR에 자동으로 빌드 및 푸시하는 스크립트

set -e

# 색상 설정
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

log_build() {
    echo -e "${CYAN}[BUILD]${NC} $1"
}

# 설정 변수
AWS_ACCOUNT_ID="949019836804"
AWS_REGION="ap-northeast-2"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
PROJECT_NAME="elice-devops"

# 지원하는 환경
ENVIRONMENTS=("dev" "stg" "prod")

# 마이크로서비스 목록
SERVICES=(
    "api-gateway"
    "user-service"
    "auth-service"
    "product-service"
    "inventory-service"
    "order-service"
    "payment-service"
    "notification-service"
    "review-service"
    "analytics-service"
    "log-service"
    "health-service"
)

# 전역 변수
BUILD_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
GIT_COMMIT_HASH=""
PUSH_LOG_FILE="ecr-push-${BUILD_TIMESTAMP}.log"
FAILED_SERVICES=()
SUCCESS_SERVICES=()

# 사용법 출력
usage() {
    echo "Elice DevOps Project - ECR Push Automation Script"
    echo ""
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  build-all <env>        - Build and push all services for environment"
    echo "  build-service <env> <service> - Build and push specific service"
    echo "  login                  - Login to ECR only"
    echo "  list-repos             - List ECR repositories"
    echo "  cleanup                - Remove local images"
    echo "  status                 - Check push status"
    echo ""
    echo "Options:"
    echo "  -v, --version <tag>    - Specify version tag (default: auto-generated)"
    echo "  -f, --force            - Force rebuild without cache"
    echo "  -p, --parallel         - Build services in parallel"
    echo "  -d, --dry-run          - Show what would be done without executing"
    echo "  --latest               - Also tag as latest"
    echo "  --no-cache             - Build without Docker cache"
    echo "  --push-only            - Skip build, push existing images"
    echo "  -h, --help             - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 build-all dev"
    echo "  $0 build-service prod user-service --version v1.2.3"
    echo "  $0 build-all stg --parallel --latest"
    echo "  $0 cleanup"
    echo ""
    echo "Environments: ${ENVIRONMENTS[*]}"
    echo "Services: ${SERVICES[*]}"
}

# Git 정보 가져오기
get_git_info() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        GIT_COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        log_info "Git commit: ${GIT_COMMIT_HASH}"
    else
        GIT_COMMIT_HASH="nogit"
        log_warning "Not a git repository"
    fi
}

# 버전 태그 생성
generate_version_tag() {
    local env=$1
    local service=$2
    
    if [ -n "$VERSION_TAG" ]; then
        echo "$VERSION_TAG"
    else
        echo "${env}-${BUILD_TIMESTAMP}-${GIT_COMMIT_HASH}"
    fi
}

# ECR 로그인
ecr_login() {
    log_step "ECR 로그인 중..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] ECR 로그인 스킵"
        return 0
    fi
    
    if aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY; then
        log_success "ECR 로그인 성공"
        return 0
    else
        log_error "ECR 로그인 실패"
        return 1
    fi
}

# ECR 리포지토리 존재 확인
check_ecr_repository() {
    local env=$1
    local service=$2
    local repo_name="${PROJECT_NAME}-${env}-${service}"
    
    log_info "ECR 리포지토리 확인: ${repo_name}"
    
    if aws ecr describe-repositories --repository-names "$repo_name" --region $AWS_REGION > /dev/null 2>&1; then
        log_success "리포지토리 존재: ${repo_name}"
        return 0
    else
        log_error "리포지토리 없음: ${repo_name}"
        return 1
    fi
}

# Docker 이미지 빌드
build_image() {
    local env=$1
    local service=$2
    local version_tag=$3
    local local_tag="${PROJECT_NAME}-${env}-${service}:${version_tag}"
    
    log_build "이미지 빌드 시작: ${service} (${env})"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] 빌드 스킵: ${local_tag}"
        return 0
    fi
    
    # 서비스 디렉토리 존재 확인
    if [ ! -d "$service" ]; then
        log_error "서비스 디렉토리 없음: $service"
        return 1
    fi
    
    cd "$service"
    
    # Docker 빌드 옵션 설정
    local build_args="--tag $local_tag"
    
    if [ "$FORCE_REBUILD" = true ] || [ "$NO_CACHE" = true ]; then
        build_args="$build_args --no-cache"
    fi
    
    # 환경별 빌드 인자 추가
    build_args="$build_args --build-arg ENV=$env"
    build_args="$build_args --build-arg BUILD_DATE=$BUILD_TIMESTAMP"
    build_args="$build_args --build-arg GIT_COMMIT=$GIT_COMMIT_HASH"
    
    log_info "빌드 명령: docker build $build_args ."
    
    if docker build $build_args . >> "../$PUSH_LOG_FILE" 2>&1; then
        log_success "이미지 빌드 성공: ${local_tag}"
        cd ..
        return 0
    else
        log_error "이미지 빌드 실패: ${local_tag}"
        cd ..
        return 1
    fi
}

# 이미지 태깅
tag_image() {
    local env=$1
    local service=$2
    local version_tag=$3
    local local_tag="${PROJECT_NAME}-${env}-${service}:${version_tag}"
    local repo_name="${PROJECT_NAME}-${env}-${service}"
    local remote_tag="${ECR_REGISTRY}/${repo_name}:${version_tag}"
    local latest_tag="${ECR_REGISTRY}/${repo_name}:latest"
    
    log_step "이미지 태깅: ${service}"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] 태깅 스킵: ${remote_tag}"
        if [ "$TAG_LATEST" = true ]; then
            log_info "[DRY-RUN] 태깅 스킵: ${latest_tag}"
        fi
        return 0
    fi
    
    # 버전 태그
    if docker tag "$local_tag" "$remote_tag"; then
        log_success "태깅 성공: ${remote_tag}"
    else
        log_error "태깅 실패: ${remote_tag}"
        return 1
    fi
    
    # latest 태그 (옵션)
    if [ "$TAG_LATEST" = true ]; then
        if docker tag "$local_tag" "$latest_tag"; then
            log_success "latest 태깅 성공: ${latest_tag}"
        else
            log_error "latest 태깅 실패: ${latest_tag}"
            return 1
        fi
    fi
    
    return 0
}

# ECR에 이미지 푸시
push_image() {
    local env=$1
    local service=$2
    local version_tag=$3
    local repo_name="${PROJECT_NAME}-${env}-${service}"
    local remote_tag="${ECR_REGISTRY}/${repo_name}:${version_tag}"
    local latest_tag="${ECR_REGISTRY}/${repo_name}:latest"
    
    log_step "ECR 푸시: ${service}"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] 푸시 스킵: ${remote_tag}"
        if [ "$TAG_LATEST" = true ]; then
            log_info "[DRY-RUN] 푸시 스킵: ${latest_tag}"
        fi
        return 0
    fi
    
    # 버전 태그 푸시
    log_info "푸시 중: ${remote_tag}"
    if docker push "$remote_tag" >> "$PUSH_LOG_FILE" 2>&1; then
        log_success "푸시 성공: ${remote_tag}"
    else
        log_error "푸시 실패: ${remote_tag}"
        return 1
    fi
    
    # latest 태그 푸시 (옵션)
    if [ "$TAG_LATEST" = true ]; then
        log_info "latest 푸시 중: ${latest_tag}"
        if docker push "$latest_tag" >> "$PUSH_LOG_FILE" 2>&1; then
            log_success "latest 푸시 성공: ${latest_tag}"
        else
            log_error "latest 푸시 실패: ${latest_tag}"
            return 1
        fi
    fi
    
    return 0
}

# 단일 서비스 처리
process_service() {
    local env=$1
    local service=$2
    local start_time=$(date +%s)
    
    log_step "서비스 처리 시작: ${service} (${env})"
    
    # ECR 리포지토리 확인
    if ! check_ecr_repository "$env" "$service"; then
        FAILED_SERVICES+=("${env}/${service}")
        return 1
    fi
    
    local version_tag=$(generate_version_tag "$env" "$service")
    
    # 이미지 빌드 (push-only 모드가 아닌 경우)
    if [ "$PUSH_ONLY" != true ]; then
        if ! build_image "$env" "$service" "$version_tag"; then
            FAILED_SERVICES+=("${env}/${service}")
            return 1
        fi
        
        # 이미지 태깅
        if ! tag_image "$env" "$service" "$version_tag"; then
            FAILED_SERVICES+=("${env}/${service}")
            return 1
        fi
    fi
    
    # ECR 푸시
    if ! push_image "$env" "$service" "$version_tag"; then
        FAILED_SERVICES+=("${env}/${service}")
        return 1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    SUCCESS_SERVICES+=("${env}/${service}")
    log_success "서비스 처리 완료: ${service} (${duration}초)"
    
    return 0
}

# 병렬 처리 함수
process_services_parallel() {
    local env=$1
    shift
    local services=("$@")
    local pids=()
    
    log_info "병렬 처리 시작 (${#services[@]}개 서비스)"
    
    for service in "${services[@]}"; do
        process_service "$env" "$service" &
        pids+=($!)
    done
    
    # 모든 병렬 작업 완료 대기
    local failed=0
    for pid in "${pids[@]}"; do
        if ! wait $pid; then
            failed=1
        fi
    done
    
    return $failed
}

# 모든 서비스 빌드 및 푸시
build_all_services() {
    local env=$1
    
    if [[ ! " ${ENVIRONMENTS[@]} " =~ " ${env} " ]]; then
        log_error "지원하지 않는 환경: $env"
        log_info "지원 환경: ${ENVIRONMENTS[*]}"
        return 1
    fi
    
    log_step "모든 서비스 빌드 시작: ${env} 환경"
    log_info "타임스탬프: ${BUILD_TIMESTAMP}"
    log_info "로그 파일: ${PUSH_LOG_FILE}"
    
    # ECR 로그인
    if ! ecr_login; then
        return 1
    fi
    
    local start_time=$(date +%s)
    
    if [ "$PARALLEL" = true ]; then
        process_services_parallel "$env" "${SERVICES[@]}"
    else
        for service in "${SERVICES[@]}"; do
            process_service "$env" "$service"
        done
    fi
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # 결과 요약
    echo ""
    log_step "=== 빌드 결과 요약 ==="
    log_info "환경: $env"
    log_info "총 소요시간: ${total_duration}초"
    log_info "성공한 서비스 (${#SUCCESS_SERVICES[@]}개):"
    for service in "${SUCCESS_SERVICES[@]}"; do
        log_success "  ✓ $service"
    done
    
    if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
        log_info "실패한 서비스 (${#FAILED_SERVICES[@]}개):"
        for service in "${FAILED_SERVICES[@]}"; do
            log_error "  ✗ $service"
        done
        return 1
    else
        log_success "모든 서비스 빌드 및 푸시 완료!"
        return 0
    fi
}

# 특정 서비스 빌드 및 푸시
build_single_service() {
    local env=$1
    local service=$2
    
    if [[ ! " ${ENVIRONMENTS[@]} " =~ " ${env} " ]]; then
        log_error "지원하지 않는 환경: $env"
        return 1
    fi
    
    if [[ ! " ${SERVICES[@]} " =~ " ${service} " ]]; then
        log_error "지원하지 않는 서비스: $service"
        return 1
    fi
    
    log_step "단일 서비스 빌드: ${service} (${env})"
    
    # ECR 로그인
    if ! ecr_login; then
        return 1
    fi
    
    process_service "$env" "$service"
}

# ECR 리포지토리 목록
list_repositories() {
    log_step "ECR 리포지토리 목록"
    aws ecr describe-repositories \
        --query 'repositories[?contains(repositoryName, `elice-devops`)].{Name:repositoryName,URI:repositoryUri,Created:createdAt}' \
        --output table
}

# 로컬 이미지 정리
cleanup_images() {
    log_step "로컬 이미지 정리"
    
    log_info "elice-devops 이미지 검색 중..."
    local images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "$PROJECT_NAME" || true)
    
    if [ -z "$images" ]; then
        log_info "정리할 이미지가 없습니다."
        return 0
    fi
    
    log_info "발견된 이미지:"
    echo "$images"
    
    echo -n "이미지를 삭제하시겠습니까? (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "$images" | xargs docker rmi -f
        log_success "이미지 정리 완료"
    else
        log_info "이미지 정리 취소"
    fi
}

# 푸시 상태 확인
check_status() {
    log_step "ECR 푸시 상태 확인"
    
    for env in "${ENVIRONMENTS[@]}"; do
        echo ""
        log_info "=== $env 환경 ==="
        for service in "${SERVICES[@]}"; do
            local repo_name="${PROJECT_NAME}-${env}-${service}"
            local image_count=$(aws ecr list-images --repository-name "$repo_name" --query 'length(imageIds)' --output text 2>/dev/null || echo "0")
            
            if [ "$image_count" -gt 0 ]; then
                log_success "$service: $image_count 개 이미지"
            else
                log_warning "$service: 이미지 없음"
            fi
        done
    done
}

# 메인 로직
main() {
    # Git 정보 가져오기
    get_git_info
    
    # 명령어에 따른 처리
    case $COMMAND in
        build-all)
            if [ -z "$ENV" ]; then
                log_error "환경을 지정해주세요: ${ENVIRONMENTS[*]}"
                exit 1
            fi
            build_all_services "$ENV"
            ;;
        build-service)
            if [ -z "$ENV" ] || [ -z "$SERVICE" ]; then
                log_error "환경과 서비스를 지정해주세요"
                exit 1
            fi
            build_single_service "$ENV" "$SERVICE"
            ;;
        login)
            ecr_login
            ;;
        list-repos)
            list_repositories
            ;;
        cleanup)
            cleanup_images
            ;;
        status)
            check_status
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

# 파라미터 파싱
VERSION_TAG=""
FORCE_REBUILD=false
PARALLEL=false
DRY_RUN=false
TAG_LATEST=false
NO_CACHE=false
PUSH_ONLY=false
COMMAND=""
ENV=""
SERVICE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION_TAG="$2"
            shift 2
            ;;
        -f|--force)
            FORCE_REBUILD=true
            shift
            ;;
        -p|--parallel)
            PARALLEL=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --latest)
            TAG_LATEST=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --push-only)
            PUSH_ONLY=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        build-all|build-service|login|list-repos|cleanup|status)
            COMMAND="$1"
            shift
            ;;
        *)
            if [ -z "$ENV" ] && [[ " ${ENVIRONMENTS[@]} " =~ " $1 " ]]; then
                ENV="$1"
            elif [ -z "$SERVICE" ] && [[ " ${SERVICES[@]} " =~ " $1 " ]]; then
                SERVICE="$1"
            else
                log_error "알 수 없는 파라미터: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# 명령어가 지정되지 않은 경우
if [ -z "$COMMAND" ]; then
    usage
    exit 1
fi

# 메인 함수 실행
main 