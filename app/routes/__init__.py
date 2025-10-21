from fastapi import APIRouter
from .process_routes import router as process_router
from .document_routes import router as document_router
from .translation_routes import router as translation_router
from .image_routes import router as image_routes
from .health import health_check
api_router = APIRouter()
api_router.include_router(process_router, prefix="/process")
api_router.include_router(document_router, prefix="/process")
api_router.include_router(translation_router, prefix="/process")
api_router.include_router(image_routes, prefix="/images")
api_router.include_router(health, prefix="/health")
# Prefix separado para images/PDF

# En main.py: app.include_router(api_router, prefix="/api") → /api/images/{img_id}, /api/images/document/{doc_id}/images, /api/images/process/{doc_id}/pdf
