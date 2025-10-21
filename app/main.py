import logging
from fastapi import FastAPI, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
from dotenv import load_dotenv
import os
from contextlib import asynccontextmanager  # Para lifespan async

from app.config import Config, CORSConfig  # Tu Config para HOST/PORT/etc.
from app.database import db_manager, get_async_db  # Singleton + dep async
from app.routes import health, images_routes, process_router  # Import via __init__.py (routers exportados)

# Load .env early
load_dotenv()

# Logging setup
log_level = getattr(logging, Config.LOG_LEVEL if hasattr(Config, 'LOG_LEVEL') else 'INFO', logging.INFO)
logging.basicConfig(level=log_level, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Lifespan: Startup/shutdown async
@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        await db_manager.initialize()
        logger.info("✅ DB inicializada con async support")
    except Exception as e:
        logger.error(f"❌ Error en startup DB: {e}", exc_info=True)
        raise
    yield
    try:
        await db_manager.close()
        logger.info("🔒 DB cerrada en shutdown")
    except Exception as e:
        logger.error(f"❌ Error en shutdown DB: {e}")

app = FastAPI(
    title="Document Viewer API",
    description="API para procesar PDFs, imágenes y traducciones con async Postgres.",
    version="1.0.0",
    lifespan=lifespan
)

# CORS
allow_origins = ["*"]  # O split de CORSConfig
app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "X-Requested-With"],
)

# FIX: Custom middleware para log requests (global, reemplaza router middleware)
@app.middleware("http")
async def log_requests(request: Request, call_next):
    logger.info(f"Request: {request.method} {request.url.path} from {request.client.host}")
    response = await call_next(request)
    logger.info(f"Response: {response.status_code} for {request.method} {request.url.path}")
    return response

# Include routers (prefix /api; asume routers sin prefix interno)
app.include_router(health_router, prefix="/api", tags=["health"])
app.include_router(process_router, prefix="/api", tags=["process"])  # /api/process
app.include_router(images_router, prefix="/api", tags=["images"])

# Root
@app.get("/")
async def read_root():
    return {"message": "API Running con FastAPI", "version": "1.0.0"}

# Quita /health si en health_router

def start_server():
    host = getattr(Config, 'HOST', '127.0.0.1')
    port = getattr(Config, 'PORT', 8000)
    logger.info(f"🚀 Servidor en http://{host}:{port}")
    import uvicorn
    uvicorn.run("app.main:app", host=host, port=port, reload=True, log_level="info")

if __name__ == "__main__":
    start_server()
