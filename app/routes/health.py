from fastapi import APIRouter

router = APIRouter(tags=["health"])  # Tags en router para Swagger

@router.get("/status", response_model=dict)
async def health_check():
    """
    Un endpoint simple para verificar que el servidor está vivo y respondiendo.
    """
    return {"status": "ok", "service": "PDF Processor", "timestamp": "2025-10-16T17:30:00"}
