#!/usr/bin/env python3
"""
Dockerfile 최적화 스크립트
각 마이크로서비스의 requirements.txt를 분석하여 최적화된 Dockerfile을 생성
"""

import os
import re
from pathlib import Path

# 서비스 디렉토리 목록
SERVICES = [
    "analytics-service", "api-gateway", "auth-service", "health-service",
    "inventory-service", "log-service", "notification-service", "order-service",
    "payment-service", "product-service", "review-service", "user-service"
]

def check_db_dependencies(requirements_file):
    """requirements.txt에서 데이터베이스 의존성 확인"""
    if not os.path.exists(requirements_file):
        return False
    
    with open(requirements_file, 'r') as f:
        content = f.read()
    
    # PostgreSQL 관련 의존성 패턴
    db_patterns = [
        r'psycopg2',
        r'sqlalchemy',
        r'alembic'
    ]
    
    return any(re.search(pattern, content, re.IGNORECASE) for pattern in db_patterns)

def generate_dockerfile(service_name, has_db_deps=False):
    """최적화된 Dockerfile 생성"""
    
    # 기본 템플릿
    dockerfile_template = """# Multi-stage build for optimized {service_name} image
FROM python:3.11-slim as builder

# Set build-time environment variables
ENV PYTHONUNBUFFERED=1 \\
    PYTHONDONTWRITEBYTECODE=1 \\
    PIP_NO_CACHE_DIR=1 \\
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install build dependencies
RUN apt-get update && apt-get install -y \\
    build-essential \\{db_deps}
    gcc \\
    && rm -rf /var/lib/apt/lists/*

# Create and activate virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install -r requirements.txt

# Production stage
FROM python:3.11-slim as production

# Set production environment variables
ENV PYTHONUNBUFFERED=1 \\
    PYTHONDONTWRITEBYTECODE=1 \\
    PATH="/opt/venv/bin:$PATH"

# Install only runtime dependencies
RUN apt-get update && apt-get install -y \\{runtime_deps}
    curl \\
    && rm -rf /var/lib/apt/lists/* \\
    && apt-get clean

# Copy virtual environment from builder stage
COPY --from=builder /opt/venv /opt/venv

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set working directory
WORKDIR /app

# Copy application code
COPY --chown=appuser:appuser . .

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Improved healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \\
    CMD curl -f http://localhost:8080/health || exit 1

# Production-ready startup command
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "{workers}"]"""

    # 의존성에 따른 설정
    if has_db_deps:
        db_deps = "\n    libpq-dev \\"
        runtime_deps = "\n    libpq5 \\"
    else:
        db_deps = " \\"
        runtime_deps = " \\"
    
    # API Gateway는 더 많은 워커 프로세스 사용
    workers = "2" if service_name == "api-gateway" else "1"
    
    return dockerfile_template.format(
        service_name=service_name,
        db_deps=db_deps,
        runtime_deps=runtime_deps,
        workers=workers
    )

def main():
    """모든 서비스에 대해 최적화된 Dockerfile 생성"""
    base_dir = Path(__file__).parent
    
    print("마이크로서비스 Dockerfile 최적화 시작...")
    print("=" * 50)
    
    for service in SERVICES:
        service_dir = base_dir / service
        requirements_file = service_dir / "requirements.txt"
        dockerfile_path = service_dir / "Dockerfile.optimized"
        
        if not service_dir.exists():
            print(f"{service} 디렉토리가 존재하지 않습니다.")
            continue
        
        # 데이터베이스 의존성 확인
        has_db_deps = check_db_dependencies(requirements_file)
        
        # 최적화된 Dockerfile 생성
        dockerfile_content = generate_dockerfile(service, has_db_deps)
        
        # 파일 저장
        with open(dockerfile_path, 'w') as f:
            f.write(dockerfile_content)
        
        print(f"{service:<25} {'(DB 의존성 있음)' if has_db_deps else '(DB 의존성 없음)'}")
    
    print("=" * 50)
    print("모든 서비스의 최적화된 Dockerfile 생성 완료!")
    print("\n 생성된 파일:")
    print("   - 각 서비스 디렉토리에 'Dockerfile.optimized' 파일 생성")
    print("   - Multi-stage build로 이미지 크기 최소화")
    print("   - Non-root user로 보안 강화")
    print("   - 레이어 캐싱 최적화")

if __name__ == "__main__":
    main() 