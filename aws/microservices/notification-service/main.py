from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from prometheus_client import Counter, Histogram, generate_latest
import uvicorn
import time

# Prometheus 메트릭
REQUEST_COUNT = Counter('notification_service_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('notification_service_request_duration_seconds', 'Request duration')

app = FastAPI(
    title="Notification Service",
    description="알림 서비스",
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
    return {"message": "알림 서비스 - Elice DevOps Mini Project", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    """헬스체크 엔드포인트"""
    return {"status": "healthy", "service": "notification-service"}

@app.get("/metrics")
async def metrics():
    """Prometheus 메트릭 엔드포인트"""
    return Response(generate_latest(), media_type="text/plain")

@app.post("/notifications")
async def post__notifications():
    """알림 발송"""
    return {"message": "알림 발송", "service": "notification-service"}

@app.get("/notifications/{user_id}")
async def get__notifications_user_id(user_id: int):
    """사용자 알림 조회"""
    return {"message": "사용자 알림 조회", "id": user_id, "service": "notification-service"}

@app.put("/notifications/{id}/read")
async def put__notifications_id_read(item_id: int):
    """알림 읽음 처리"""
    return {"message": "알림 읽음 처리", "id": item_id, "service": "notification-service"}

@app.get("/templates")
async def get__templates():
    """알림 템플릿 조회"""
    return {"message": "알림 템플릿 조회", "service": "notification-service"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
