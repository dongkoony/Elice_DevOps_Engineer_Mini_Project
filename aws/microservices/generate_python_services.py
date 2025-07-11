#!/usr/bin/env python3
"""
12개 마이크로서비스를 Python FastAPI로 자동 생성하는 스크립트
"""

import os
import json

# 서비스 정의
services = {
    "auth-service": {
        "description": "인증 및 권한 관리 서비스",
        "port": 8080,
        "database": "auth_db",
        "endpoints": [
            {"path": "/token", "method": "POST", "description": "JWT 토큰 발급"},
            {"path": "/verify", "method": "POST", "description": "토큰 검증"},
            {"path": "/refresh", "method": "POST", "description": "토큰 갱신"},
            {"path": "/logout", "method": "POST", "description": "로그아웃"},
        ]
    },
    "product-service": {
        "description": "상품 관리 서비스",
        "port": 8080,
        "database": "product_db",
        "endpoints": [
            {"path": "/products", "method": "GET", "description": "상품 목록 조회"},
            {"path": "/products", "method": "POST", "description": "상품 생성"},
            {"path": "/products/{id}", "method": "GET", "description": "상품 상세 조회"},
            {"path": "/products/{id}", "method": "PUT", "description": "상품 수정"},
            {"path": "/products/{id}", "method": "DELETE", "description": "상품 삭제"},
            {"path": "/categories", "method": "GET", "description": "카테고리 조회"},
        ]
    },
    "inventory-service": {
        "description": "재고 관리 서비스",
        "port": 8080,
        "database": "inventory_db",
        "endpoints": [
            {"path": "/inventory/{product_id}", "method": "GET", "description": "재고 조회"},
            {"path": "/inventory/{product_id}", "method": "PUT", "description": "재고 업데이트"},
            {"path": "/inventory/reserve", "method": "POST", "description": "재고 예약"},
            {"path": "/inventory/release", "method": "POST", "description": "재고 해제"},
        ]
    },
    "order-service": {
        "description": "주문 관리 서비스",
        "port": 8080,
        "database": "order_db",
        "endpoints": [
            {"path": "/orders", "method": "GET", "description": "주문 목록 조회"},
            {"path": "/orders", "method": "POST", "description": "주문 생성"},
            {"path": "/orders/{id}", "method": "GET", "description": "주문 상세 조회"},
            {"path": "/orders/{id}/status", "method": "PUT", "description": "주문 상태 변경"},
            {"path": "/orders/{id}/cancel", "method": "POST", "description": "주문 취소"},
        ]
    },
    "payment-service": {
        "description": "결제 처리 서비스",
        "port": 8080,
        "database": "payment_db",
        "endpoints": [
            {"path": "/payments", "method": "POST", "description": "결제 처리"},
            {"path": "/payments/{id}", "method": "GET", "description": "결제 상세 조회"},
            {"path": "/payments/{id}/refund", "method": "POST", "description": "환불 처리"},
            {"path": "/payments/methods", "method": "GET", "description": "결제 수단 조회"},
        ]
    },
    "notification-service": {
        "description": "알림 서비스",
        "port": 8080,
        "database": "notification_db",
        "endpoints": [
            {"path": "/notifications", "method": "POST", "description": "알림 발송"},
            {"path": "/notifications/{user_id}", "method": "GET", "description": "사용자 알림 조회"},
            {"path": "/notifications/{id}/read", "method": "PUT", "description": "알림 읽음 처리"},
            {"path": "/templates", "method": "GET", "description": "알림 템플릿 조회"},
        ]
    },
    "review-service": {
        "description": "리뷰 및 평점 서비스",
        "port": 8080,
        "database": "review_db",
        "endpoints": [
            {"path": "/reviews", "method": "GET", "description": "리뷰 목록 조회"},
            {"path": "/reviews", "method": "POST", "description": "리뷰 작성"},
            {"path": "/reviews/{id}", "method": "GET", "description": "리뷰 상세 조회"},
            {"path": "/reviews/{id}", "method": "PUT", "description": "리뷰 수정"},
            {"path": "/reviews/{id}", "method": "DELETE", "description": "리뷰 삭제"},
            {"path": "/products/{id}/reviews", "method": "GET", "description": "상품별 리뷰 조회"},
        ]
    },
    "analytics-service": {
        "description": "분석 데이터 서비스",
        "port": 8080,
        "database": "analytics_db",
        "endpoints": [
            {"path": "/analytics/sales", "method": "GET", "description": "매출 분석"},
            {"path": "/analytics/users", "method": "GET", "description": "사용자 분석"},
            {"path": "/analytics/products", "method": "GET", "description": "상품 분석"},
            {"path": "/analytics/dashboard", "method": "GET", "description": "대시보드 데이터"},
        ]
    },
    "log-service": {
        "description": "로그 수집 및 관리 서비스",
        "port": 8080,
        "database": "log_db",
        "endpoints": [
            {"path": "/logs", "method": "POST", "description": "로그 수집"},
            {"path": "/logs", "method": "GET", "description": "로그 조회"},
            {"path": "/logs/search", "method": "GET", "description": "로그 검색"},
            {"path": "/logs/stats", "method": "GET", "description": "로그 통계"},
        ]
    },
    "health-service": {
        "description": "시스템 헬스체크 및 모니터링 서비스",
        "port": 8080,
        "database": "health_db",
        "endpoints": [
            {"path": "/system/health", "method": "GET", "description": "전체 시스템 헬스체크"},
            {"path": "/services/status", "method": "GET", "description": "서비스별 상태 조회"},
            {"path": "/metrics/summary", "method": "GET", "description": "메트릭 요약"},
            {"path": "/alerts", "method": "GET", "description": "알람 조회"},
        ]
    }
}

def create_main_py(service_name, service_config):
    """FastAPI main.py 파일 생성"""
    endpoints_code = ""
    
    for endpoint in service_config["endpoints"]:
        method = endpoint["method"].lower()
        path = endpoint["path"]
        desc = endpoint["description"]
        
        if "{id}" in path or "{product_id}" in path or "{user_id}" in path:
            param_name = "item_id"
            if "{product_id}" in path:
                param_name = "product_id"
            elif "{user_id}" in path:
                param_name = "user_id"
            
            endpoints_code += f'''
@app.{method}("{path}")
async def {method}_{path.replace("/", "_").replace("{", "").replace("}", "").replace("-", "_")}({param_name}: int):
    """{desc}"""
    return {{"message": "{desc}", "id": {param_name}, "service": "{service_name}"}}
'''
        else:
            endpoints_code += f'''
@app.{method}("{path}")
async def {method}_{path.replace("/", "_").replace("-", "_")}():
    """{desc}"""
    return {{"message": "{desc}", "service": "{service_name}"}}
'''

    return f'''from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from prometheus_client import Counter, Histogram, generate_latest
import uvicorn
import time

# Prometheus 메트릭
REQUEST_COUNT = Counter('{service_name.replace("-", "_")}_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('{service_name.replace("-", "_")}_request_duration_seconds', 'Request duration')

app = FastAPI(
    title="{service_name.replace('-', ' ').title()}",
    description="{service_config['description']}",
    version="1.0.0"
)

@app.middleware("http")
async def add_process_time_header(request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()
    REQUEST_DURATION.observe(process_time)
    
    response.headers["X-Process-Time"] = str(process_time)
    return response

@app.get("/")
async def root():
    return {{"message": "{service_config['description']} - Elice DevOps Mini Project", "version": "1.0.0"}}

@app.get("/health")
async def health_check():
    """헬스체크 엔드포인트"""
    return {{"status": "healthy", "service": "{service_name}"}}

@app.get("/metrics")
async def metrics():
    """Prometheus 메트릭 엔드포인트"""
    return Response(generate_latest(), media_type="text/plain")
{endpoints_code}
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port={service_config['port']})
'''

def create_requirements_txt():
    """requirements.txt 파일 생성"""
    return '''fastapi==0.104.1
uvicorn[standard]==0.24.0
prometheus-client==0.19.0
python-multipart==0.0.6
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
pydantic==2.5.1
'''

def create_dockerfile():
    """Dockerfile 생성"""
    return '''FROM python:3.11-slim

WORKDIR /app

# 시스템 의존성 설치
RUN apt-get update && apt-get install -y \\
    curl \\
    && rm -rf /var/lib/apt/lists/*

# Python 의존성 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 앱 코드 복사
COPY . .

# 포트 노출
EXPOSE 8080

# 헬스체크
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \\
    CMD curl -f http://localhost:8080/health || exit 1

# 앱 실행
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
'''

def create_service(service_name, service_config):
    """개별 서비스 디렉토리 및 파일 생성"""
    service_dir = service_name
    
    # 디렉토리 생성
    os.makedirs(service_dir, exist_ok=True)
    
    # main.py 생성
    with open(f"{service_dir}/main.py", "w", encoding="utf-8") as f:
        f.write(create_main_py(service_name, service_config))
    
    # requirements.txt 생성
    with open(f"{service_dir}/requirements.txt", "w", encoding="utf-8") as f:
        f.write(create_requirements_txt())
    
    # Dockerfile 생성
    with open(f"{service_dir}/Dockerfile", "w", encoding="utf-8") as f:
        f.write(create_dockerfile())
    
    print(f"✅ {service_name} 생성 완료")

def main():
    """메인 함수"""
    print("🚀 Python FastAPI 마이크로서비스 생성 시작...")
    
    for service_name, service_config in services.items():
        create_service(service_name, service_config)
    
    print(f"\\n🎉 총 {len(services)}개 서비스 생성 완료!")
    print("\\n📋 생성된 서비스 목록:")
    for service_name, service_config in services.items():
        print(f"  - {service_name}: {service_config['description']}")
    
    # 서비스 정보를 JSON으로 저장
    with open("services_info.json", "w", encoding="utf-8") as f:
        json.dump(services, f, ensure_ascii=False, indent=2)
    
    print("\\n📄 서비스 정보가 services_info.json에 저장되었습니다.")

if __name__ == "__main__":
    main() 