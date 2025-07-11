from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from prometheus_client import Counter, Histogram, generate_latest
import uvicorn
import time

# Prometheus 메트릭
REQUEST_COUNT = Counter('payment_service_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('payment_service_request_duration_seconds', 'Request duration')

app = FastAPI(
    title="Payment Service",
    description="결제 처리 서비스",
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
    return {"message": "결제 처리 서비스 - Elice DevOps Mini Project", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    """헬스체크 엔드포인트"""
    return {"status": "healthy", "service": "payment-service"}

@app.get("/metrics")
async def metrics():
    """Prometheus 메트릭 엔드포인트"""
    return Response(generate_latest(), media_type="text/plain")

@app.post("/payments")
async def post__payments():
    """결제 처리"""
    return {"message": "결제 처리", "service": "payment-service"}

@app.get("/payments/{id}")
async def get__payments_id(item_id: int):
    """결제 상세 조회"""
    return {"message": "결제 상세 조회", "id": item_id, "service": "payment-service"}

@app.post("/payments/{id}/refund")
async def post__payments_id_refund(item_id: int):
    """환불 처리"""
    return {"message": "환불 처리", "id": item_id, "service": "payment-service"}

@app.get("/payments/methods")
async def get__payments_methods():
    """결제 수단 조회"""
    return {"message": "결제 수단 조회", "service": "payment-service"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
