import logging
from typing import Dict, Any
from deep_translator import GoogleTranslator
import asyncio
import time  # Para rate-limit simple

logger = logging.getLogger(__name__)


class TranslationService:
    SUPPORTED_LANGUAGES = {
        "es": "es", "en": "en", "fr": "fr",  # Google codes direct
        "de": "de", "it": "it", "pt": "pt",  # pt para pt-BR/PT
        "ja": "ja", "zh": "zh-CN", "ko": "ko",
        "ru": "ru", "ar": "ar", "hi": "hi"  # Más common; agrega si needed
    }

    _last_request_time = 0
    _rate_limit_delay = 1.0  # 1s entre calls (evita bans Google)

    @staticmethod
    async def translate_text(text: str, target_lang: str, source_lang: str = "auto") -> str:
        """Fix: Reordena params: required (text, target) antes de default (source)."""
        if not text or source_lang == target_lang:
            return text

        # Rate limit simple (class-level)
        now = time.time()
        if now - TranslationService._last_request_time < TranslationService._rate_limit_delay:
            delay = TranslationService._rate_limit_delay - (now - TranslationService._last_request_time)
            await asyncio.sleep(delay)
        TranslationService._last_request_time = time.time()

        try:
            # Fix: Wrap la llamada completa translate en to_thread (GoogleTranslator sync)
            source_code = source_lang if source_lang != "auto" else "auto"
            target_code = TranslationService.SUPPORTED_LANGUAGES.get(target_lang, target_lang)
            translator = GoogleTranslator(source=source_code, target=target_code)
            translated = await asyncio.to_thread(translator.translate, text)
            return translated or text  # Fallback si None/empty
        except Exception as e:
            logger.error(f"Error translating text to {target_lang}: {e}")
            return text  # Fallback original

    @staticmethod
    async def translate_document(document_dict: Dict[str, Any], target_lang: str, source_lang: str = "auto") -> Dict[str, Any]:
        if target_lang not in TranslationService.SUPPORTED_LANGUAGES:
            raise ValueError(f"Target lang '{target_lang}' not supported. Use: {list(TranslationService.SUPPORTED_LANGUAGES.keys())}")

        translated_doc = document_dict.copy()
        target_code = TranslationService.SUPPORTED_LANGUAGES[target_lang]
        source_code = source_lang if source_lang != "auto" else "auto"

        # Translate pages texts async (batch con gather)
        tasks = []
        for page in translated_doc.get("pages", []):
            if page.get("text"):
                # Fix: Usa nuevo order en translate_text
                tasks.append(
                    TranslationService.translate_text(page["text"], target_lang, source_lang)
                )
            else:
                tasks.append(asyncio.create_task(asyncio.sleep(0)))  # No-op si no text

        translated_texts = await asyncio.gather(*tasks, return_exceptions=True)

        # Apply results (handle exceptions)
        for i, page in enumerate(translated_doc.get("pages", [])):
            result = translated_texts[i]
            if isinstance(result, Exception):
                logger.warning(f"Translation failed for page {page.get('page_number', i+1)}: {result}")
                # Keep original
                continue
            else:
                page["text"] = result
                logger.info(f"Translated page {page.get('page_number', i+1)} to {target_lang}")

        # Continuous para translated (merge post-translate)
        continuous_text = "\n".join(p.get("text", "") for p in translated_doc.get("pages", [])).strip()
        translated_doc["continuousText"] = continuous_text

        # globalImages same (no translate images)
        if "globalImages" in translated_doc:
            pass  # Ya copiado en copy()
        elif "pages" in translated_doc:
            # Build si no (de original via copy)
            global_images = []
            offset = 0
            for page in translated_doc["pages"]:
                for img in page.get("images", []):
                    global_images.append({
                        "id": img["id"],
                        "extension": img["extension"],
                        "page_offset": offset
                    })
                offset += len(page.get("text", ""))
            translated_doc["globalImages"] = global_images

        # Total_pages y metadata same
        translated_doc["target_language"] = target_lang  # Agrega para repo (is_translation=True)

        logger.info(f"Document translated: {len(translated_doc.get('pages', []))} pages to {target_lang}")
        return translated_doc
