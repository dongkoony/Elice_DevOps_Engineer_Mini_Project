#!/bin/bash

# Elice DevOps Project - Docker Compose Management Script
# 전체 마이크로서비스 아키텍처를 쉽게 관리하기 위한 스크립트

set -e

# 색상 설정
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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 사용법 출력
usage() {
    echo "Elice DevOps Project - Docker Management Script"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  build         - Build all service images"
    echo "  up            - Start all services"
    echo "  down          - Stop all services"
    echo "  restart       - Restart all services"
    echo "  logs          - Show logs for all services"
    echo "  logs <service> - Show logs for specific service"
    echo "  status        - Show status of all services"
    echo "  clean         - Remove all containers and images"
    echo "  health        - Check health of all services"
    echo "  db-init       - Initialize database"
    echo "  test          - Run basic connectivity tests"
    echo ""
    echo "Options:"
    echo "  -d, --detach  - Run in detached mode"
    echo "  -f, --force   - Force operation"
    echo "  -v, --verbose - Verbose output"
    echo ""
    echo "Examples:"
    echo "  $0 build"
    echo "  $0 up -d"
    echo "  $0 logs user-service"
    echo "  $0 clean -f"
}

# 서비스 목록
SERVICES=(
    "postgres"
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

# 서비스 포트 매핑
declare -A SERVICE_PORTS=(
    ["postgres"]="5432"
    ["api-gateway"]="8080"
    ["user-service"]="8081"
    ["auth-service"]="8082"
    ["product-service"]="8083"
    ["inventory-service"]="8084"
    ["order-service"]="8085"
    ["payment-service"]="8086"
    ["notification-service"]="8087"
    ["review-service"]="8088"
    ["analytics-service"]="8089"
    ["log-service"]="8090"
    ["health-service"]="8091"
)

# Docker Compose 파일 존재 확인
check_compose_file() {
    if [ ! -f "docker-compose.yml" ]; then
        log_error "docker-compose.yml 파일이 존재하지 않습니다."
        exit 1
    fi
}

# 모든 이미지 빌드
build_all() {
    log_info "모든 서비스 이미지 빌드 시작..."
    
    if [ "$VERBOSE" = true ]; then
        docker-compose build --parallel
    else
        docker-compose build --parallel > /dev/null 2>&1
    fi
    
    log_success "모든 서비스 이미지 빌드 완료"
}

# 모든 서비스 시작
start_all() {
    log_info "모든 서비스 시작 중..."
    
    if [ "$DETACH" = true ]; then
        docker-compose up -d
    else
        docker-compose up
    fi
    
    log_success "모든 서비스 시작 완료"
}

# 모든 서비스 중지
stop_all() {
    log_info "모든 서비스 중지 중..."
    docker-compose down
    log_success "모든 서비스 중지 완료"
}

# 모든 서비스 재시작
restart_all() {
    log_info "모든 서비스 재시작 중..."
    docker-compose restart
    log_success "모든 서비스 재시작 완료"
}

# 로그 출력
show_logs() {
    if [ -n "$1" ]; then
        log_info "$1 서비스 로그 출력..."
        docker-compose logs -f "$1"
    else
        log_info "모든 서비스 로그 출력..."
        docker-compose logs -f
    fi
}

# 서비스 상태 확인
show_status() {
    log_info "서비스 상태 확인 중..."
    echo ""
    printf "%-25s %-10s %-15s %-10s\n" "SERVICE" "STATUS" "PORT" "HEALTH"
    printf "%-25s %-10s %-15s %-10s\n" "-------" "------" "----" "------"
    
    for service in "${SERVICES[@]}"; do
        container_name="elice-${service}"
        if [ "$service" = "postgres" ]; then
            container_name="elice-postgres"
        fi
        
        status=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "$container_name" | awk '{print $2}' || echo "Stopped")
        port=${SERVICE_PORTS[$service]}
        
        # 헬스체크
        if [ "$status" = "Up" ]; then
            if [ "$service" = "postgres" ]; then
                health="✓"
            else
                health_check=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port/health" 2>/dev/null || echo "000")
                if [ "$health_check" = "200" ]; then
                    health="✓"
                else
                    health="✗"
                fi
            fi
        else
            health="✗"
        fi
        
        printf "%-25s %-10s %-15s %-10s\n" "$service" "$status" "$port" "$health"
    done
}

# 헬스체크 수행
health_check() {
    log_info "전체 시스템 헬스체크 시작..."
    
    failed_services=()
    
    for service in "${SERVICES[@]}"; do
        if [ "$service" = "postgres" ]; then
            continue
        fi
        
        port=${SERVICE_PORTS[$service]}
        
        log_info "$service 헬스체크 중... (포트: $port)"
        
        response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port/health" 2>/dev/null || echo "000")
        
        if [ "$response" = "200" ]; then
            log_success "$service: 정상"
        else
            log_error "$service: 실패 (HTTP $response)"
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        log_success "모든 서비스가 정상적으로 작동 중입니다."
    else
        log_error "실패한 서비스: ${failed_services[*]}"
        exit 1
    fi
}

# 시스템 정리
clean_all() {
    if [ "$FORCE" = true ]; then
        log_warning "모든 컨테이너 및 이미지 강제 삭제 중..."
        docker-compose down -v --rmi all --remove-orphans
    else
        log_info "모든 컨테이너 중지 및 삭제 중..."
        docker-compose down -v --remove-orphans
    fi
    
    log_success "시스템 정리 완료"
}

# 데이터베이스 초기화
init_database() {
    log_info "데이터베이스 초기화 중..."
    
    # PostgreSQL 컨테이너가 실행 중인지 확인
    if ! docker ps | grep -q "elice-postgres"; then
        log_error "PostgreSQL 컨테이너가 실행 중이 아닙니다."
        log_info "먼저 'docker-compose up -d postgres' 실행해주세요."
        exit 1
    fi
    
    # 데이터베이스 초기화 스크립트 실행
    docker exec elice-postgres psql -U elice_user -d elice_db -f /docker-entrypoint-initdb.d/init-db.sql
    
    log_success "데이터베이스 초기화 완료"
}

# 기본 연결 테스트
test_connectivity() {
    log_info "기본 연결 테스트 시작..."
    
    # API Gateway 테스트
    log_info "API Gateway 연결 테스트..."
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/health" 2>/dev/null || echo "000")
    if [ "$response" = "200" ]; then
        log_success "API Gateway: 연결 성공"
    else
        log_error "API Gateway: 연결 실패"
    fi
    
    # 데이터베이스 테스트
    log_info "데이터베이스 연결 테스트..."
    if docker exec elice-postgres pg_isready -U elice_user -d elice_db > /dev/null 2>&1; then
        log_success "PostgreSQL: 연결 성공"
    else
        log_error "PostgreSQL: 연결 실패"
    fi
    
    log_success "기본 연결 테스트 완료"
}

# 파라미터 파싱
DETACH=false
FORCE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--detach)
            DETACH=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            COMMAND="$1"
            SERVICE_NAME="$2"
            shift
            ;;
    esac
done

# 기본 검증
check_compose_file

# 명령어 실행
case $COMMAND in
    build)
        build_all
        ;;
    up)
        start_all
        ;;
    down)
        stop_all
        ;;
    restart)
        restart_all
        ;;
    logs)
        show_logs "$SERVICE_NAME"
        ;;
    status)
        show_status
        ;;
    health)
        health_check
        ;;
    clean)
        clean_all
        ;;
    db-init)
        init_database
        ;;
    test)
        test_connectivity
        ;;
    *)
        usage
        exit 1
        ;;
esac 