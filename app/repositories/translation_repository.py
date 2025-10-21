import logging
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.exc import SQLAlchemyError
from typing import Dict, Optional
from app.database.models import Document, Page
from .document_queries import DocumentQueries  # Para get_document en translation_id

logger = logging.getLogger(__name__)


class TranslationRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.queries = DocumentQueries(session)  # Compone para get_translation

    async def save_translation(self, document_id: str, target_lang: str, translated_data: Dict) -> bool:
        async with self.session.begin():
            try:
                # Obtén original para link
                original_stmt = select(Document).where(Document.id == document_id)
                original_result = await self.session.execute(original_stmt)
                original = original_result.scalar_one_or_none()
                if not original:
                    logger.warning(f"Original no encontrado para traducción: {document_id}")
                    return False

                translation_id = f"{document_id}_translated_{target_lang}"
                continuous_text = translated_data.get("continuousText", original.continuous_text or "")

                translation = Document(
                    id=translation_id,
                    filename=f"{original.filename} ({target_lang})",
                    total_pages=translated_data["total_pages"],
                    is_translation=True,
                    original_document_id=document_id,
                    target_language=target_lang,
                    continuous_text=continuous_text
                )
                self.session.add(translation)

                for page_data in translated_data["pages"]:
                    page_id = f"{translation_id}_page_{page_data['page_number']}"
                    page = Page(
                        id=page_id,
                        document_id=translation_id,
                        page_number=page_data["page_number"],
                        text=page_data["text"],  # Texto traducido
                        width=int(page_data["dimensions"]["width"]),
                        height=int(page_data["dimensions"]["height"])
                    )
                    self.session.add(page)
                    # No duplica images; usa original si needed via queries

                await self.session.flush()

                logger.info(f"📝 Traducción async guardada: {translation_id}")
                return True
            except SQLAlchemyError as e:
                logger.error(f"Error async save translation {document_id}: {e}")
                raise
            except Exception as e:
                logger.error(f"Error inesperado en save_translation {document_id}: {e}", exc_info=True)
                raise

    async def get_translation(self, document_id: str, target_lang: str) -> Optional[Dict]:
        """Delegado a queries para full merged response (modo continuous por default)."""
        translation_id = f"{document_id}_translated_{target_lang}"
        return await self.queries.get_document(translation_id, include_images=False, mode="continuous")
