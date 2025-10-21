import os
from dotenv import load_dotenv
from typing import Optional

load_dotenv()

class Config:
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO").upper()

    # Validación básica (evita crashes si env mal)
    @classmethod
    def validate(cls):
        if cls.PORT < 1 or cls.PORT > 65535:
            raise ValueError("PORT debe ser 1-65535")
        return True

class PostgresConfig:
    HOST: str = os.getenv("POSTGRES_HOST", "localhost")
    PORT: int = int(os.getenv("POSTGRES_PORT", "5432"))
    DATABASE: str = os.getenv("POSTGRES_DB", "pdf_processor")
    USER: str = os.getenv("POSTGRES_USER", "pdfuser")
    PASSWORD: Optional[str] = os.getenv("POSTGRES_PASSWORD")  # Allow None for testing

    @classmethod
    def get_connection_string(cls, async_mode: bool = True) -> str:
        url = f"postgresql://{cls.USER}:{cls.PASSWORD or ''}@{cls.HOST}:{cls.PORT}/{cls.DATABASE}"
        if async_mode:
            url = url.replace("postgresql://", "postgresql+asyncpg://")  # Async driver para FastAPI
        return url

    @classmethod
    def validate(cls):
        if not all([cls.HOST, cls.DATABASE, cls.USER]):
            raise ValueError("POSTGRES_HOST, POSTGRES_DB, POSTGRES_USER requeridos")
        return True

class CORSConfig:
    ALLOW_ORIGIN: str = os.getenv("CORS_ALLOW_ORIGIN", "*")
    ALLOW_METHODS: str = os.getenv("CORS_ALLOW_METHODS", "GET, POST, DELETE, OPTIONS")
    ALLOW_HEADERS: str = os.getenv("CORS_ALLOW_HEADERS", "Content-Type, Authorization")

    @classmethod
    def get_middleware_config(cls):
        """Para FastAPI middleware (ya en main.py); no headers manuales como Robyn."""
        return {
            "allow_origins": [cls.ALLOW_ORIGIN] if cls.ALLOW_ORIGIN != "*" else ["*"],
            "allow_methods": cls.ALLOW_METHODS.split(", "),
            "allow_headers": cls.ALLOW_HEADERS.split(", "),
        }

# Init en main.py si needed
Config.validate()
PostgresConfig.validate()
