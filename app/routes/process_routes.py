import logging
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from app.database.connection import get_async_db
from app.repositories.document_repository import DocumentRepository
from app.services.pdf_processor import PDFProcessorService

logger = logging.getLogger(__name__)

router = APIRouter(tags=["process"])  # Tags para docs

@router.post("/process", response_model=dict, status_code=201)
async def process_pdf(
    file: UploadFile = File(..., description="Archivo PDF a procesar"),
    session: AsyncSession = Depends(get_async_db)
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

        document_dict = await PDFProcessorService.process_pdf(pdf_bytes, file.filename)
        logger.info(f"Document processed: ID={document_dict.get('id')}, pages={document_dict.get('total_pages')}")

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


@router.get("/process/status")
async def process_status(session: AsyncSession = Depends(get_async_db)):
    return {"status": "Process module ready", "db_connected": True}
