import logging
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.exc import SQLAlchemyError
from typing import Dict
from app.database.models import Document, Page, Image
from app.utils.base64_helper import safe_decode_base64

logger = logging.getLogger(__name__)


class DocumentMutations:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def save_document(self, document_data: Dict, compute_continuous: bool = True) -> bool:
        async with self.session.begin():
            try:
                if not all(key in document_data for key in ["id", "filename", "total_pages", "pages"]):
                    raise ValueError("document_data incompleto")

                continuous_text = document_data.get("continuousText", "")
                if not continuous_text and compute_continuous:
                    continuous_text = "\n".join([page_data.get("text", "") for page_data in document_data["pages"]])
                    continuous_text = continuous_text.strip()

                document = Document(
                    id=document_data["id"],
                    filename=document_data["filename"],
                    total_pages=document_data["total_pages"],
                    is_translation=False,
                    continuous_text=continuous_text
                )

                if "globalImages" in document_data:
                    logger.info(f"Global images pre-computed: {len(document_data['globalImages'])}")

                self.session.add(document)

                for page_data in document_data["pages"]:
                    page_id = f"{document_data['id']}_page_{page_data['page_number']}"
                    page = Page(
                        id=page_id,
                        document_id=document_data["id"],
                        page_number=page_data["page_number"],
                        text=page_data.get("text", ""),
                        width=int(page_data["dimensions"]["width"]),
                        height=int(page_data["dimensions"]["height"])
                    )
                    self.session.add(page)

                    for img_data in page_data.get("images", []):
                        img_b64 = img_data.get("data", "")
                        image_bytes = safe_decode_base64(img_b64)  # Usa util
                        if image_bytes is None:
                            logger.warning(f"Imagen inválida en {img_data.get('id', 'unknown')}")
                            continue
                        image = Image(
                            id=img_data.get("id", f"{page_id}_img_{len(page_data.get('images', []))}"),
                            page_id=page_id,
                            image_data=image_bytes,
                            extension=img_data.get("extension", "png")
                        )
                        self.session.add(image)

                await self.session.flush()

                logger.info(f"📝 Guardado async: {document_data['id']} (continuous: {bool(continuous_text)})")
                return True
            except (ValueError, SQLAlchemyError) as e:
                logger.error(f"Error async guardando doc {document_data.get('id', 'unknown')}: {e}")
                raise
            except Exception as e:
                logger.error(f"Error inesperado en save: {e}", exc_info=True)
                raise

    async def delete_document(self, document_id: str) -> bool:
        async with self.session.begin():
            try:
                from sqlalchemy import select
                stmt = select(Document).where(Document.id == document_id)
                result = await self.session.execute(stmt)
                document = result.scalar_one_or_none()
                if not document:
                    return False
                await self.session.delete(document)  # Cascade delete pages/images via relations
                logger.info(f"🗑️ Doc async eliminado: {document_id}")
                return True
            except Exception as e:
                logger.error(f"Error async delete {document_id}: {e}")
                raise
