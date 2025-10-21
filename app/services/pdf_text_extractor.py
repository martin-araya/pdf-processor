import logging
import asyncio
import io
from typing import str
from PIL import Image  # Para OCR si needed

logger = logging.getLogger(__name__)


class PDFTextExtractor:
    def __init__(self):
        # Stub para OCR; instala pytesseract si usas
        pass

    async def extract_text_from_page(self, page) -> str:
        """Extrae texto de página con fitz (sync via thread). Fallback OCR si vacío."""
        try:
            # Sync op fast; to_thread para async compat
            text = await asyncio.to_thread(page.get_text, "text")
            text = text.strip()
            if not text:
                # Fallback OCR stub (expande si needed)
                text = await self._ocr_page_image(page)
            return text
        except Exception as e:
            logger.error(f"Error extracting text from page: {e}")
            return ""

    async def _ocr_page_image(self, page) -> str:
        """Stub OCR: Usa pytesseract en imagen de página si text vacío (opcional)."""
        try:
            # Render page to image sync
            pix = await asyncio.to_thread(page.get_pixmap)
            img_bytes = pix.tobytes("png")
            # Ej: from pytesseract import image_to_string; return await asyncio.to_thread(image_to_string, Image.open(io.BytesIO(img_bytes)))
            logger.info("OCR stub: Implementa pytesseract si needed")
            return ""  # Placeholder
        except Exception as e:
            logger.error(f"OCR error: {e}")
            return ""

    def merge_continuous_text(self, current_text: str, page_text: str, page_offset: int) -> str:
        """Merge texto continuo con \n gap (simple; expande para offsets si needed)."""
        if page_text:
            return current_text + page_text + "\n"
        return current_text
