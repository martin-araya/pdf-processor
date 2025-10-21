import uuid
import logging
import io
import asyncio
import fitz  # PyMuPDF
from typing import Dict, Any, List
from .pdf_text_extractor import PDFTextExtractor
from .pdf_image_extractor import PDFImageExtractor
from .table_detector import TableDetector

logger = logging.getLogger(__name__)


class PDFProcessorService:
    def __init__(self):
        self.text_extractor = PDFTextExtractor()
        self.image_extractor = PDFImageExtractor()
        self.table_detector = TableDetector()

    async def process_pdf(self, pdf_bytes: bytes, filename: str) -> Dict[str, Any]:
        if len(pdf_bytes) > 100 * 1024 * 1024:  # 100MB limit
            raise ValueError("PDF too large (>100MB)")

        document_id = str(uuid.uuid4())
        pdf_document = None
        try:
            # Async open via thread (fitz sync I/O)
            pdf_document = await asyncio.to_thread(
                fitz.open, stream=io.BytesIO(pdf_bytes), filetype="pdf"
            )
            pages = []
            continuous_text = ""
            global_images = []
            all_tables = []
            page_offset = 0

            for page_num in range(len(pdf_document)):
                page = pdf_document[page_num]
                rect = page.rect

                # Extrae por página (async)
                page_text = await self.text_extractor.extract_text_from_page(page)
                page_images = await self.image_extractor.extract_images_from_page(
                    page, page_num + 1, document_id
                )
                page_tables = await self.table_detector.detect_tables_in_page(page, page_text)

                # Merge continuous (usa helper)
                continuous_text = self.text_extractor.merge_continuous_text(continuous_text, page_text, page_offset)

                # Global images con position (usa extractor helper)
                page_global_images = self.image_extractor.build_global_images(page_images, page_offset)
                global_images.extend(page_global_images)

                # Merge tables global (para visualization)
                all_tables.extend(page_tables)

                pages.append({
                    "page_number": page_num + 1,
                    "text": page_text,
                    "images": page_images,
                    "tables": page_tables,  # Por página
                    "dimensions": {"width": rect.width, "height": rect.height}
                })

                page_offset += len(page_text)

            # Close via thread
            await asyncio.to_thread(pdf_document.close)

            # Build full dict
            doc_dict = {
                "id": document_id,
                "filename": filename,
                "total_pages": len(pages),
                "pages": pages,
                "continuousText": continuous_text.strip(),
                "globalImages": global_images,
                "allTables": all_tables  # Merge para frontend sort/visualization
            }
            logger.info(f"PDF processed: {document_id}, {len(pages)} pages, tables: {len(all_tables)}")
            return doc_dict

        except ValueError as ve:
            logger.error(f"Value error in PDF process: {ve}")
            raise
        except Exception as e:
            logger.error(f"Error processing PDF '{filename}': {e}", exc_info=True)
            if pdf_document:
                await asyncio.to_thread(pdf_document.close)
            raise ValueError("Failed to process PDF")
