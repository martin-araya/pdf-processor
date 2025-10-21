import logging
from fastapi import APIRouter, Depends, HTTPException, Path
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi.responses import StreamingResponse
from app.database.connection import get_async_db
from app.repositories.document_repository import DocumentRepository

logger = logging.getLogger(__name__)

router = APIRouter(tags=["images"])  # Tags para docs

@router.get("/{image_id}", response_model=dict)
async def get_image(
    image_id: str = Path(..., description="ID de la imagen"),
    session: AsyncSession = Depends(get_async_db)
):
    repo = DocumentRepository(session)  # Usa session inyectada
    try:
        image = await repo.get_image(image_id)
        if not image:
            raise HTTPException(status_code=404, detail={"error": "Imagen no encontrada"})
        logger.info(f"Imagen servida: {image_id}")
        return image  # {"id": "...", "data": "data:image/png;base64,...", "extension": "png", "page_id": "..."}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching image {image_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail={"error": f"Error interno: {str(e)}"})


@router.get("/document/{doc_id}/images", response_model=dict)
async def get_document_images(
    doc_id: str = Path(..., description="ID del documento"),
    session: AsyncSession = Depends(get_async_db)
):
    repo = DocumentRepository(session)  # Usa session
    try:
        image_ids = await repo.get_document_images(doc_id)
        logger.info(f"Imágenes listadas para doc {doc_id}: {len(image_ids)}")
        return {
            "document_id": doc_id,
            "image_ids": image_ids,
            "count": len(image_ids)
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error listing images for doc {doc_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail={"error": f"Error interno: {str(e)}"})


@router.get("/process/{doc_id}/pdf", response_class=StreamingResponse)
async def get_pdf(
    doc_id: str = Path(..., description="ID del documento"),
    session: AsyncSession = Depends(get_async_db)
):
    repo = DocumentRepository(session)
    try:
        document = await repo.get_document(doc_id, include_images=False, mode="paged")  # Valida existencia
        if not document:
            raise HTTPException(status_code=404, detail={"error": "PDF no encontrado"})

        # FIX: Implementa fetch real de bytes (e.g., si agregas pdf_bytes a Document model en save_document)
        # Opción 1: Si saved en DB: pdf_bytes = document.get('pdf_bytes', b'')  # Asume field
        # Opción 2: Fetch de storage: pdf_bytes = await fetch_from_storage(document['filename'])  # Crea util
        # Opción 3: Regenera con processor si no saved (pero ineficiente)
        # Por ahora: Dummy error/bytes; reemplaza con real
        pdf_bytes = b"%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj 2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj 3 0 obj<</Type/Page/MediaBox[0 0 612 792]>>endobj trailer<</Size 4/Root 1 0 R>>%%EOF"  # Minimal dummy PDF bytes

        return StreamingResponse(
            iter([pdf_bytes]),
            media_type="application/pdf",
            headers={
                "Content-Disposition": f"attachment; filename=\"{document['filename']}\"",
                "Content-Length": str(len(pdf_bytes))
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching PDF {doc_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail={"error": "Error en PDF"})
