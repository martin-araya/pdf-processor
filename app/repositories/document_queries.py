import base64
import logging
import traceback
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import selectinload
from typing import Dict, List, Optional
from app.database.models import Document, Page, Image
from app.utils.table_heuristics import detect_tables_in_text
from app.utils.position_calculator import calculate_relative_position, calculate_continuous_position

logger = logging.getLogger(__name__)


class DocumentQueries:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_document(self, document_id: str, include_images: bool = False, mode: str = "paged") -> Optional[Dict]:
        async with self.session.begin():
            try:
                stmt = select(Document).where(Document.id == document_id)
                if include_images:
                    stmt = stmt.options(selectinload(Document.pages).selectinload(Page.images))
                else:
                    stmt = stmt.options(selectinload(Document.pages))

                result = await self.session.execute(stmt)
                document: Optional[Document] = result.scalar_one_or_none()

                if not document:
                    logger.warning(f"Doc no encontrado en DB: {document_id}")
                    return None

                pages_list = []
                continuous_text = document.continuous_text or ""
                global_images_list = []
                all_tables = []
                page_offset = 0

                for page in document.pages:
                    page_dict = {
                        "page_number": page.page_number,
                        "text": page.text or "",
                        "dimensions": {"width": page.width, "height": page.height},
                        "tables": detect_tables_in_text(page.text or ""),  # Usa util
                        "image_ids": [img.id for img in page.images] if include_images else []
                    }
                    all_tables.extend(page_dict["tables"])  # Merge para visualization

                    if include_images and hasattr(page, 'images') and page.images:
                        page_dict["images"] = []
                        for img in page.images:
                            bounds = getattr(img, 'bounds', {}) or {'x': page.width // 4, 'y': page.height // 4,
                                                                    'width': 200, 'height': 150}
                            position = calculate_relative_position(bounds, page.width, page.height)  # Usa util
                            img_bytes = bytes(img.image_data)
                            data_uri = f"data:image/{img.extension};base64,{base64.b64encode(img_bytes).decode('utf-8')}"
                            page_dict["images"].append({
                                "id": img.id,
                                "data": data_uri,
                                "extension": img.extension,
                                "position": position
                            })

                    pages_list.append(page_dict)

                    if mode == "continuous":
                        page_text = page.text or ""
                        continuous_text += page_text + "\n"
                        if include_images and hasattr(page, 'images') and page.images:
                            char_offset = page_offset
                            for img in page.images:
                                img_pos = calculate_continuous_position(page_offset, char_offset)  # Usa util
                                global_images_list.append({
                                    "id": img.id,
                                    "extension": img.extension,
                                    "page_offset": img_pos["page_offset"],
                                    "relative_pos": img_pos["relative_pos"]
                                })
                            char_offset += len(page_text)
                        page_offset += len(page_text)

                if mode == "continuous" and not document.continuous_text:
                    document.continuous_text = continuous_text.strip()
                    self.session.add(document)
                    await self.session.commit()

                return self._build_response(document, pages_list, continuous_text, global_images_list, all_tables, mode)
            except SQLAlchemyError as e:
                logger.error(f"Error async query doc {document_id}: {e}", exc_info=True)
                return None
            except Exception as e:
                logger.error(f"Error inesperado en get_doc {document_id}: {e}", exc_info=True)
                traceback.print_exc()
                return None

    def _build_response(self, document, pages_list, continuous_text, global_images_list, all_tables, mode):
        """Helper interno para construir JSON basado en mode (evita duplicación)."""
        base_return = {
            "id": str(document.id),
            "filename": document.filename,
            "total_pages": document.total_pages,
            "created_at": document.created_at.isoformat() if document.created_at else None,
            "pages": pages_list,
            "target_language": getattr(document, 'target_language', None)
        }
        if mode == "continuous":
            base_return.update({
                "continuousText": continuous_text.strip(),
                "globalImages": global_images_list
            })
        elif mode == "visualization":
            base_return.update({
                "allTables": all_tables,
                "globalImages": global_images_list
            })
        return base_return

    async def get_image(self, image_id: str) -> Optional[Dict]:
        async with self.session.begin():
            try:
                stmt = select(Image).where(Image.id == image_id)
                result = await self.session.execute(stmt)
                image: Optional[Image] = result.scalar_one_or_none()
                if not image:
                    return None

                img_bytes = bytes(image.image_data)
                from app.utils.base64_helper import encode_to_data_uri  # Import local
                data_uri = encode_to_data_uri(img_bytes, image.extension)
                return {
                    "id": image.id,
                    "data": data_uri,
                    "extension": image.extension,
                    "page_id": image.page_id
                }
            except SQLAlchemyError as e:
                logger.error(f"Error async get image {image_id}: {e}")
                return None
            except Exception as e:
                logger.error(f"Error en get_image {image_id}: {e}")
                return None

    async def get_document_images(self, document_id: str) -> List[str]:
        async with self.session.begin():
            try:
                stmt = select(Image.id).join(Page).join(Document).where(Document.id == document_id)
                result = await self.session.execute(stmt)
                return [row[0] for row in result.fetchall()]
            except Exception as e:
                logger.error(f"Error async images doc {document_id}: {e}")
                return []
