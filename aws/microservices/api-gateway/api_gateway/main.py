from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import httpx
import asyncio
import time
import logging
from prometheus_client import Counter, Histogram, generate_latest
from fastapi.responses import Response
import uvicorn

# Prometheus 메트릭
REQUEST_COUNT = Counter('api_gateway_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('api_gateway_request_duration_seconds', 'Request duration')

app = FastAPI(
    title="API Gateway",
    description="마이크로서비스 API Gateway",
    version="1.0.0"
)

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 서비스 라우팅 테이블
SERVICES = {
    "/users": "http://user-service:8080",
    "/auth": "http://auth-service:8080", 
    "/products": "http://product-service:8080",
    "/inventory": "http://inventory-service:8080",
    "/orders": "http://order-service:8080",
    "/payments": "http://payment-service:8080",
    "/notifications": "http://notification-service:8080",
    "/reviews": "http://review-service:8080",
    "/analytics": "http://analytics-service:8080",
    "/logs": "http://log-service:8080",
}

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    
    # Prometheus 메트릭 기록
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
    return {"message": "API Gateway - Elice DevOps Mini Project", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    """헬스체크 엔드포인트"""
    health_status = {"status": "healthy", "services": {}}
    
    # 각 서비스의 헬스체크
    async with httpx.AsyncClient(timeout=5.0) as client:
        for prefix, url in SERVICES.items():
            try:
                response = await client.get(f"{url}/health")
                health_status["services"][prefix.strip("/")] = {
                    "status": "healthy" if response.status_code == 200 else "unhealthy",
                    "response_time": response.elapsed.total_seconds()
                }
            except Exception as e:
                health_status["services"][prefix.strip("/")] = {
                    "status": "unhealthy",
                    "error": str(e)
                }
    
    return health_status

@app.get("/metrics")
async def metrics():
    """Prometheus 메트릭 엔드포인트"""
    return Response(generate_latest(), media_type="text/plain")

# 동적 라우팅 - 모든 요청을 해당 서비스로 전달
@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy_request(request: Request, path: str):
    """요청을 적절한 마이크로서비스로 프록시"""
    
    # 경로 매칭
    target_service = None
    for prefix, service_url in SERVICES.items():
        if f"/{path}".startswith(prefix):
            target_service = service_url
            # prefix 제거
            path = f"/{path}"[len(prefix):]
            if not path.startswith("/"):
                path = "/" + path
            break
    
    if not target_service:
        raise HTTPException(status_code=404, detail="Service not found")
    
    # 요청 전달
    url = f"{target_service}{path}"
    query_params = str(request.url.query)
    if query_params:
        url += f"?{query_params}"
    
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            # 요청 본문 읽기
            body = await request.body()
            
            response = await client.request(
                method=request.method,
                url=url,
                headers=dict(request.headers),
                content=body
            )
            
            # 응답 헤더에서 제외할 키들
            excluded_headers = {
                'content-encoding', 'content-length', 'transfer-encoding', 'connection'
            }
            headers = {
                key: value for key, value in response.headers.items()
                if key.lower() not in excluded_headers
            }
            
            return Response(
                content=response.content,
                status_code=response.status_code,
                headers=headers
            )
            
        except httpx.TimeoutException:
            logger.error(f"Timeout calling {url}")
            raise HTTPException(status_code=504, detail="Service timeout")
        except httpx.ConnectError:
            logger.error(f"Connection error to {url}")
            raise HTTPException(status_code=502, detail="Service unavailable")
        except Exception as e:
            logger.error(f"Error proxying request to {url}: {str(e)}")
            raise HTTPException(status_code=500, detail="Internal server error")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080) 