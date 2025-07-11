from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from prometheus_client import Counter, Histogram, generate_latest
import uvicorn
import time

# Prometheus 메트릭
REQUEST_COUNT = Counter('analytics_service_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('analytics_service_request_duration_seconds', 'Request duration')

app = FastAPI(
    title="Analytics Service",
    description="분석 데이터 서비스",
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
    return {"message": "분석 데이터 서비스 - Elice DevOps Mini Project", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    """헬스체크 엔드포인트"""
    return {"status": "healthy", "service": "analytics-service"}

@app.get("/metrics")
async def metrics():
    """Prometheus 메트릭 엔드포인트"""
    return Response(generate_latest(), media_type="text/plain")

@app.get("/analytics/sales")
async def get__analytics_sales():
    """매출 분석"""
    return {"message": "매출 분석", "service": "analytics-service"}

@app.get("/analytics/users")
async def get__analytics_users():
    """사용자 분석"""
    return {"message": "사용자 분석", "service": "analytics-service"}

@app.get("/analytics/products")
async def get__analytics_products():
    """상품 분석"""
    return {"message": "상품 분석", "service": "analytics-service"}

@app.get("/analytics/dashboard")
async def get__analytics_dashboard():
    """대시보드 데이터"""
    return {"message": "대시보드 데이터", "service": "analytics-service"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
