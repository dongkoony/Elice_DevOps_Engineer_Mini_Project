from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from prometheus_client import Counter, Histogram, generate_latest
import uvicorn
import time

# Prometheus 메트릭
REQUEST_COUNT = Counter('log_service_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('log_service_request_duration_seconds', 'Request duration')

app = FastAPI(
    title="Log Service",
    description="로그 수집 및 관리 서비스",
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
    return {"message": "로그 수집 및 관리 서비스 - Elice DevOps Mini Project", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    """헬스체크 엔드포인트"""
    return {"status": "healthy", "service": "log-service"}

@app.get("/metrics")
async def metrics():
    """Prometheus 메트릭 엔드포인트"""
    return Response(generate_latest(), media_type="text/plain")

@app.post("/logs")
async def post__logs():
    """로그 수집"""
    return {"message": "로그 수집", "service": "log-service"}

@app.get("/logs")
async def get__logs():
    """로그 조회"""
    return {"message": "로그 조회", "service": "log-service"}

@app.get("/logs/search")
async def get__logs_search():
    """로그 검색"""
    return {"message": "로그 검색", "service": "log-service"}

@app.get("/logs/stats")
async def get__logs_stats():
    """로그 통계"""
    return {"message": "로그 통계", "service": "log-service"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
