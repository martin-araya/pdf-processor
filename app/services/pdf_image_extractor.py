import base64
import logging
import asyncio
from typing import List, Dict, Any
from app.utils.base64_helper import encode_to_data_uri
from app.utils.position_calculator import calculate_relative_position

logger = logging.getLogger(__name__)


class PDFImageExtractor:
    def __init__(self, max_images_per_page: int = 10):
        self.max_images = max_images_per_page

    async def extract_images_from_page(self, page, page_number: int, document_id: str) -> List[Dict[str, Any]]:
        """Extrae imágenes con fitz, encode base64 vía util, sin positions (agrega en build_global)."""
        images = []
        try:
            img_list = await asyncio.to_thread(page.get_images, full=True)
            for img_index, img in enumerate(img_list[:self.max_images]):
                xref = img[0]
                base_image = await asyncio.to_thread(page.parent.extract_image, xref)
                image_bytes = base_image["image"]
                data_uri = encode_to_data_uri(image_bytes, base_image.get("ext", "png"))  # Usa util

                # Bounds approx: Si fitz da bbox, usa; sino placeholder para position calc
                bbox = base_image.get("bbox", (0, 0, 100, 100))  # Default small
                images.append({
                    "id": f"{document_id}_p{page_number}_img{img_index}",
                    "data": data_uri,
                    "extension": base_image.get("ext", "png"),
                    "bounds": {"x": bbox[0], "y": bbox[1], "width": bbox[2] - bbox[0], "height": bbox[3] - bbox[1]}
                    # Para position %
                })
            logger.info(f"Extracted {len(images)} images from page {page_number}")
        except Exception as e:
            logger.error(f"Error extracting images from page {page_number}: {e}")
        return images

    def build_global_images(self, page_images: List[Dict[str, Any]], page_offset: int) -> List[Dict[str, Any]]:
        """Construye global_images con page_offset y relative_pos % (usa util; approx center si no bounds)."""
        global_images = []
        if not page_images:
            return global_images

        # Asume page dimensions de caller (o hardcode approx 800x1100 para letter)
        approx_width, approx_height = 800, 1100
        for img in page_images:
            bounds = img.get("bounds", {})
            position = calculate_relative_position(bounds, approx_width, approx_height)  # Usa util
            global_images.append({
                "id": img["id"],
                "extension": img["extension"],
                "page_offset": page_offset,  # Para insert en continuousText
                "relative_pos": position  # % x/y/width/height para overlay en frontend
            })
        return global_images
