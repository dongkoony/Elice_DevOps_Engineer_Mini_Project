from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from prometheus_client import Counter, Histogram, generate_latest
import uvicorn
import time

# Prometheus 메트릭
REQUEST_COUNT = Counter('order_service_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('order_service_request_duration_seconds', 'Request duration')

app = FastAPI(
    title="Order Service",
    description="주문 관리 서비스",
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
    return {"message": "주문 관리 서비스 - Elice DevOps Mini Project", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    """헬스체크 엔드포인트"""
    return {"status": "healthy", "service": "order-service"}

@app.get("/metrics")
async def metrics():
    """Prometheus 메트릭 엔드포인트"""
    return Response(generate_latest(), media_type="text/plain")

@app.get("/orders")
async def get__orders():
    """주문 목록 조회"""
    return {"message": "주문 목록 조회", "service": "order-service"}

@app.post("/orders")
async def post__orders():
    """주문 생성"""
    return {"message": "주문 생성", "service": "order-service"}

@app.get("/orders/{id}")
async def get__orders_id(item_id: int):
    """주문 상세 조회"""
    return {"message": "주문 상세 조회", "id": item_id, "service": "order-service"}

@app.put("/orders/{id}/status")
async def put__orders_id_status(item_id: int):
    """주문 상태 변경"""
    return {"message": "주문 상태 변경", "id": item_id, "service": "order-service"}

@app.post("/orders/{id}/cancel")
async def post__orders_id_cancel(item_id: int):
    """주문 취소"""
    return {"message": "주문 취소", "id": item_id, "service": "order-service"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
