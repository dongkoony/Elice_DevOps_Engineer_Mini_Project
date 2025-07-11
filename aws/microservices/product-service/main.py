from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from prometheus_client import Counter, Histogram, generate_latest
import uvicorn
import time

# Prometheus 메트릭
REQUEST_COUNT = Counter('product_service_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('product_service_request_duration_seconds', 'Request duration')

app = FastAPI(
    title="Product Service",
    description="상품 관리 서비스",
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
    return {"message": "상품 관리 서비스 - Elice DevOps Mini Project", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    """헬스체크 엔드포인트"""
    return {"status": "healthy", "service": "product-service"}

@app.get("/metrics")
async def metrics():
    """Prometheus 메트릭 엔드포인트"""
    return Response(generate_latest(), media_type="text/plain")

@app.get("/products")
async def get__products():
    """상품 목록 조회"""
    return {"message": "상품 목록 조회", "service": "product-service"}

@app.post("/products")
async def post__products():
    """상품 생성"""
    return {"message": "상품 생성", "service": "product-service"}

@app.get("/products/{id}")
async def get__products_id(item_id: int):
    """상품 상세 조회"""
    return {"message": "상품 상세 조회", "id": item_id, "service": "product-service"}

@app.put("/products/{id}")
async def put__products_id(item_id: int):
    """상품 수정"""
    return {"message": "상품 수정", "id": item_id, "service": "product-service"}

@app.delete("/products/{id}")
async def delete__products_id(item_id: int):
    """상품 삭제"""
    return {"message": "상품 삭제", "id": item_id, "service": "product-service"}

@app.get("/categories")
async def get__categories():
    """카테고리 조회"""
    return {"message": "카테고리 조회", "service": "product-service"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
