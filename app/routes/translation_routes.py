import logging
from fastapi import APIRouter, Depends, HTTPException, Path
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from typing import Optional
from app.database.connection import get_async_db
from app.repositories.document_repository import DocumentRepository
from app.services.translation import TranslationService  # Asume existe; refactor si needed

logger = logging.getLogger(__name__)

router = APIRouter(tags=["translations"])

class TranslationRequest(BaseModel):
    target_lang: str
    source_lang: Optional[str] = "auto"


@router.post("/process/{doc_id}/translate", response_model=dict)
async def translate_document(
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


@router.get("/process/{doc_id}/translation/{lang}", response_model=dict)
async def get_translation(
    doc_id: str = Path(..., description="ID del documento"),
    lang: str = Path(..., description="Idioma objetivo (e.g., 'en')"),
    session: AsyncSession = Depends(get_async_db)
):
    repo = DocumentRepository(session)
    try:
        translation = await repo.get_translation(doc_id, lang)
        if not translation:
            raise HTTPException(status_code=404, detail={"error": "Traducción no encontrada"})
        return translation
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error en get_translation {doc_id} → {lang}: {e}")
        raise HTTPException(status_code=500, detail={"error": str(e)})
