import logging
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Dict, List, Optional
from .document_queries import DocumentQueries
from .document_mutations import DocumentMutations
from .translation_repository import TranslationRepository

logger = logging.getLogger(__name__)


class DocumentRepository:
    """Facade para operaciones de documentos (compone queries, mutations y translations)."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.queries = DocumentQueries(session)
        self.mutations = DocumentMutations(session)
        self.translations = TranslationRepository(session)

    # Re-expone métodos principales (facade pattern, compatibilidad)
    async def get_document(self, document_id: str, include_images: bool = False, mode: str = "paged") -> Optional[Dict]:
        return await self.queries.get_document(document_id, include_images, mode)

    async def get_image(self, image_id: str) -> Optional[Dict]:
        return await self.queries.get_image(image_id)

    async def get_document_images(self, document_id: str) -> List[str]:
        return await self.queries.get_document_images(document_id)

    async def save_document(self, document_data: Dict, compute_continuous: bool = True) -> bool:
        return await self.mutations.save_document(document_data, compute_continuous)

    async def delete_document(self, document_id: str) -> bool:
        return await self.mutations.delete_document(document_id)

    async def save_translation(self, document_id: str, target_lang: str, translated_data: Dict) -> bool:
        return await self.translations.save_translation(document_id, target_lang, translated_data)

    async def get_translation(self, document_id: str, target_lang: str) -> Optional[Dict]:
        return await self.translations.get_translation(document_id, target_lang)

    async def document_exists(self, document_id: str) -> bool:
        """Verificación simple de existencia (query básica, no full load)."""
        try:
            async with self.session.begin():
                from sqlalchemy import select
                from app.database.models import Document
                stmt = select(Document.id).where(Document.id == document_id)
                result = await self.session.execute(stmt)
                return result.scalar() is not None
        except Exception as e:
            logger.error(f"Error async exists {document_id}: {e}")
            return False
