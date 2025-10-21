import logging
from fastapi import APIRouter, Depends, HTTPException, Path, Query, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from typing import Optional
from app.database.connection import get_async_db  # Import dep
from app.repositories.document_repository import DocumentRepository
from app.services.pdf_processor import PDFProcessorService  # Async process_pdf
from app.services.translation import TranslationService  # Async translate_document
from app.config import CORSConfig  # Opcional

logger = logging.getLogger(__name__)

router = APIRouter(tags=["process"])  # Sin prefix (usa main /api)

class TranslationRequest(BaseModel):
    target_lang: str
    source_lang: Optional[str] = "auto"


@router.post("/process", response_model=dict, status_code=201)  # /api/process (ya OK)
async def process_pdf(
    file: UploadFile = File(..., description="Archivo PDF a procesar"),
    session: AsyncSession = Depends(get_async_db)  # Dep inyecta session
):
    logger.info(f"Procesando PDF: '{file.filename}' (content-type: {file.content_type})")

    if not file.filename or not file.filename.lower().endswith('.pdf'):
        raise HTTPException(status_code=400, detail={"error": "Archivo debe ser PDF"})

    if file.content_type != 'application/pdf':
        raise HTTPException(status_code=400, detail={"error": "Content-type debe ser application/pdf"})

    try:
        pdf_bytes = await file.read()
        logger.info(f"PDF bytes loaded: {len(pdf_bytes)} bytes")

        if not pdf_bytes:
            raise HTTPException(status_code=400, detail={"error": "Archivo PDF vacío"})

        # Await async service
        document_dict = await PDFProcessorService.process_pdf(pdf_bytes, file.filename)
        logger.info(f"Document processed: ID={document_dict.get('id')}, pages={document_dict.get('total_pages')}")

        # Usa session inyectada
        repo = DocumentRepository(session)
        if not await repo.save_document(document_dict, compute_continuous=False):
            raise HTTPException(status_code=500, detail={"error": "Error al guardar en DB"})

        return {
            "id": document_dict["id"],
            "filename": document_dict["filename"],
            "total_pages": document_dict["total_pages"],
            "message": "PDF procesado y guardado exitosamente",
            "status": "success"
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error procesando PDF: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail={"error": f"Error inesperado: {str(e)}"})


@router.get("/process/{doc_id}", response_model=dict)  # FIX: "/process/{doc_id}" → Full /api/process/{doc_id} con main prefix="/api"
async def get_document(
    doc_id: str = Path(..., description="ID del documento"),  # description para docs; no alias needed
    include_images: bool = Query(False, description="Incluir datos de imágenes"),
    mode: str = Query("paged", description="Modo: 'paged' o 'continuous' para texto merged"),
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
        logger.error(f"Error en get_document {doc_id}: {e}", exc_info=True)  # Agrega log para debug
        raise HTTPException(status_code=500, detail={"error": str(e)})

@router.post("/process/{doc_id}/translate", response_model=dict)  # FIX: "/process/{doc_id}/translate" → /api/process/{doc_id}/translate
async def translate(
    doc_id: str = Path(..., description="ID del documento"),
    request: TranslationRequest = Depends(),
    session: AsyncSession = Depends(get_async_db)
):
    target_lang = request.target_lang
    source_lang = request.source_lang

    repo = DocumentRepository(session)
    try:
        cached = await repo.get_translation(doc_id, target_lang)
        if cached:
            return cached

        original = await repo.get_document(doc_id, include_images=False, mode="paged")
        if not original:
            raise HTTPException(status_code=404, detail={"error": "Documento original no encontrado"})

        translated = await TranslationService.translate_document(original, target_lang, source_lang)
        await repo.save_translation(doc_id, target_lang, translated)

        return translated
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error en traducción {doc_id} → {target_lang}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail={"error": str(e)})


@router.delete("/process/{doc_id}", response_model=dict, status_code=200)  # FIX: "/process/{doc_id}" → /api/process/{doc_id}
async def delete(
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
        raise HTTPException(status_code=500, detail={"error": str(e)})


@router.get("/process/status")  # FIX: "/process/status" → /api/process/status (consistente)
async def process_status(session: AsyncSession = Depends(get_async_db)):
    return {"status": "Process module ready", "db_connected": True}
