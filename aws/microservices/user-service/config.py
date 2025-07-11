import os
from pydantic import BaseSettings

class Settings(BaseSettings):
    # JWT 설정
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-super-secret-key-change-in-production")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
    
    # 데이터베이스 설정
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "postgresql://user_db_user:user_db_password@user-db.cluster-xxx.amazonaws.com:5432/user_db"
    )
    
    # 앱 설정
    APP_NAME: str = "User Service"
    VERSION: str = "1.0.0"
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"
    
    class Config:
        env_file = ".env"

settings = Settings() 