import logging
from fastapi import APIRouter, Depends, HTTPException, Path, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database.connection import get_async_db
from app.repositories.document_repository import DocumentRepository

logger = logging.getLogger(__name__)

router = APIRouter(tags=["documents"])  # Tags separados

@router.get("/process/{doc_id}", response_model=dict)
async def get_document(
    doc_id: str = Path(..., description="ID del documento"),
    include_images: bool = Query(False, description="Incluir datos de imágenes"),
    mode: str = Query("paged", description="Modo: 'paged', 'continuous' o 'visualization'"),
    session: AsyncSession = Depends(get_async_db)
):
    repo = DocumentRepository(session)
    try:
        document = await repo.get_document(doc_id, include_images=include_images, mode=mode)
        if not document:
            raise HTTPException(status_code=404, detail={"error": "Documento no encontrado"})
        return document
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error en get_document {doc_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail={"error": str(e)})


@router.delete("/process/{doc_id}", response_model=dict, status_code=200)
async def delete_document(
    doc_id: str = Path(..., description="ID del documento"),
    session: AsyncSession = Depends(get_async_db)
):
    repo = DocumentRepository(session)
    try:
        if not await repo.document_exists(doc_id):
            raise HTTPException(status_code=404, detail={"error": "Documento no encontrado"})

        if await repo.delete_document(doc_id):
            return {"message": "Documento eliminado", "id": doc_id, "status": "success"}
        else:
            raise HTTPException(status_code=500, detail={"error": "Error al eliminar"})
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error en delete {doc_id}: {e}")
        raise HTTPException(status_code=500, detail={"error": str(e)})
