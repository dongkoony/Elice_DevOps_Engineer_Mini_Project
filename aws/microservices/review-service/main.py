from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from prometheus_client import Counter, Histogram, generate_latest
import uvicorn
import time

# Prometheus 메트릭
REQUEST_COUNT = Counter('review_service_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('review_service_request_duration_seconds', 'Request duration')

app = FastAPI(
    title="Review Service",
    description="리뷰 및 평점 서비스",
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
    return {"message": "리뷰 및 평점 서비스 - Elice DevOps Mini Project", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    """헬스체크 엔드포인트"""
    return {"status": "healthy", "service": "review-service"}

@app.get("/metrics")
async def metrics():
    """Prometheus 메트릭 엔드포인트"""
    return Response(generate_latest(), media_type="text/plain")

@app.get("/reviews")
async def get__reviews():
    """리뷰 목록 조회"""
    return {"message": "리뷰 목록 조회", "service": "review-service"}

@app.post("/reviews")
async def post__reviews():
    """리뷰 작성"""
    return {"message": "리뷰 작성", "service": "review-service"}

@app.get("/reviews/{id}")
async def get__reviews_id(item_id: int):
    """리뷰 상세 조회"""
    return {"message": "리뷰 상세 조회", "id": item_id, "service": "review-service"}

@app.put("/reviews/{id}")
async def put__reviews_id(item_id: int):
    """리뷰 수정"""
    return {"message": "리뷰 수정", "id": item_id, "service": "review-service"}

@app.delete("/reviews/{id}")
async def delete__reviews_id(item_id: int):
    """리뷰 삭제"""
    return {"message": "리뷰 삭제", "id": item_id, "service": "review-service"}

@app.get("/products/{id}/reviews")
async def get__products_id_reviews(item_id: int):
    """상품별 리뷰 조회"""
    return {"message": "상품별 리뷰 조회", "id": item_id, "service": "review-service"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
