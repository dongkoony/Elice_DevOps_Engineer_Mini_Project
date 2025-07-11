from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from prometheus_client import Counter, Histogram, generate_latest
import uvicorn
import time

# Prometheus 메트릭
REQUEST_COUNT = Counter('health_service_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('health_service_request_duration_seconds', 'Request duration')

app = FastAPI(
    title="Health Service",
    description="시스템 헬스체크 및 모니터링 서비스",
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
    return {"message": "시스템 헬스체크 및 모니터링 서비스 - Elice DevOps Mini Project", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    """헬스체크 엔드포인트"""
    return {"status": "healthy", "service": "health-service"}

@app.get("/metrics")
async def metrics():
    """Prometheus 메트릭 엔드포인트"""
    return Response(generate_latest(), media_type="text/plain")

@app.get("/system/health")
async def get__system_health():
    """전체 시스템 헬스체크"""
    return {"message": "전체 시스템 헬스체크", "service": "health-service"}

@app.get("/services/status")
async def get__services_status():
    """서비스별 상태 조회"""
    return {"message": "서비스별 상태 조회", "service": "health-service"}

@app.get("/metrics/summary")
async def get__metrics_summary():
    """메트릭 요약"""
    return {"message": "메트릭 요약", "service": "health-service"}

@app.get("/alerts")
async def get__alerts():
    """알람 조회"""
    return {"message": "알람 조회", "service": "health-service"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
