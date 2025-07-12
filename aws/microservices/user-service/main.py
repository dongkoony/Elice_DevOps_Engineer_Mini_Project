from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import datetime, timedelta
from typing import Optional, List
import uvicorn
import hashlib
import jwt
import time
from prometheus_client import Counter, Histogram, generate_latest
from fastapi.responses import Response

from database import get_db, User
from config import settings

# Prometheus 메트릭
REQUEST_COUNT = Counter('user_service_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('user_service_request_duration_seconds', 'Request duration')
USER_OPERATIONS = Counter('user_service_operations_total', 'User operations', ['operation'])

app = FastAPI(
    title="User Service",
    description="사용자 관리 마이크로서비스",
    version="1.0.0"
)

security = HTTPBearer()

# Pydantic 모델
class UserCreate(BaseModel):
    username: str
    email: EmailStr
    password: str
    full_name: Optional[str] = None

class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    full_name: Optional[str]
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    is_active: Optional[bool] = None

class LoginRequest(BaseModel):
    username: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

# 유틸리티 함수
def hash_password(password: str) -> str:
    """비밀번호 해시화"""
    return hashlib.sha256((password + settings.SECRET_KEY).encode()).hexdigest()

def verify_password(password: str, hashed: str) -> bool:
    """비밀번호 검증"""
    return hash_password(password) == hashed

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """JWT 토큰 생성"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm="HS256")
    return encoded_jwt

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security), db: Session = Depends(get_db)):
    """현재 사용자 정보 가져오기"""
    try:
        payload = jwt.decode(credentials.credentials, settings.SECRET_KEY, algorithms=["HS256"])
        username: str = payload.get("sub")
        if username is None:
            raise HTTPException(status_code=401, detail="Invalid token")
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    user = db.query(User).filter(User.username == username).first()
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    return user

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
    return {"message": "User Service - Elice DevOps Mini Project", "version": "1.0.0"}

@app.get("/health")
async def health_check(db: Session = Depends(get_db)):
    """헬스체크 엔드포인트"""
    try:
        # 데이터베이스 연결 확인
        db.execute(text("SELECT 1"))
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Database connection failed: {str(e)}")

@app.get("/metrics")
async def metrics():
    """Prometheus 메트릭 엔드포인트"""
    return Response(generate_latest(), media_type="text/plain")

@app.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register_user(user: UserCreate, db: Session = Depends(get_db)):
    """사용자 등록"""
    USER_OPERATIONS.labels(operation="register").inc()
    
    # 중복 사용자명 확인
    if db.query(User).filter(User.username == user.username).first():
        raise HTTPException(status_code=400, detail="Username already exists")
    
    # 중복 이메일 확인
    if db.query(User).filter(User.email == user.email).first():
        raise HTTPException(status_code=400, detail="Email already exists")
    
    # 새 사용자 생성
    hashed_password = hash_password(user.password)
    db_user = User(
        username=user.username,
        email=user.email,
        password_hash=hashed_password,
        full_name=user.full_name
    )
    
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    
    return db_user

@app.post("/login", response_model=TokenResponse)
async def login(login_data: LoginRequest, db: Session = Depends(get_db)):
    """사용자 로그인"""
    USER_OPERATIONS.labels(operation="login").inc()
    
    user = db.query(User).filter(User.username == login_data.username).first()
    if not user or not verify_password(login_data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    if not user.is_active:
        raise HTTPException(status_code=401, detail="User account is disabled")
    
    access_token = create_access_token(data={"sub": user.username})
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/users/me", response_model=UserResponse)
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    """현재 사용자 정보 조회"""
    USER_OPERATIONS.labels(operation="get_profile").inc()
    return current_user

@app.get("/users", response_model=List[UserResponse])
async def list_users(
    skip: int = 0, 
    limit: int = 100, 
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """사용자 목록 조회 (인증 필요)"""
    USER_OPERATIONS.labels(operation="list_users").inc()
    users = db.query(User).offset(skip).limit(limit).all()
    return users

@app.get("/users/{user_id}", response_model=UserResponse)
async def get_user(user_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """특정 사용자 정보 조회"""
    USER_OPERATIONS.labels(operation="get_user").inc()
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@app.put("/users/me", response_model=UserResponse)
async def update_current_user(
    user_update: UserUpdate, 
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """현재 사용자 정보 업데이트"""
    USER_OPERATIONS.labels(operation="update_profile").inc()
    
    # 이메일 중복 확인
    if user_update.email and user_update.email != current_user.email:
        existing_user = db.query(User).filter(User.email == user_update.email).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Email already exists")
    
    # 업데이트할 필드만 변경
    update_data = user_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(current_user, field, value)
    
    current_user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(current_user)
    
    return current_user

@app.delete("/users/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_current_user(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """현재 사용자 계정 삭제"""
    USER_OPERATIONS.labels(operation="delete_profile").inc()
    db.delete(current_user)
    db.commit()

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080) 