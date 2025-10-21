import logging
import asyncio
from typing import List, Dict, Any
from app.utils.table_heuristics import detect_tables_in_text

logger = logging.getLogger(__name__)

# Opcional: tabula-py para fallback (instala: pip install tabula-py; requiere Java)
try:
    import tabula

    TABULA_AVAILABLE = True
except ImportError:
    TABULA_AVAILABLE = False
    logger.warning("tabula-py no disponible; usa solo heurística para tablas")


class TableDetector:
    def __init__(self):
        pass

    async def detect_tables_in_page(self, page, page_text: str) -> List[Dict[str, Any]]:
        """Detecta tablas: heurística en texto + fallback tabula en PDF page (extrae como list of dicts rows/cols)."""
        tables = []
        # Paso 1: Heurística en texto extraído (rápido, para simple |-/=)
        text_tables = detect_tables_in_text(page_text)  # Usa util
        tables.extend(
            [{"type": "text", "rows": t["rows"], "is_header": t["is_header"], "offset_chars": t["offset_chars"]} for t
             in text_tables])

        # Paso 2: Fallback tabula si available (para tablas visuales en PDF; async via thread)
        if TABULA_AVAILABLE and page_text.strip():  # Solo si texto no vacío
            try:
                # Render page to image o usa area; tabula lee directo PDF bytes (necesita full doc?)
                # Simplificado: Asume caller pasa pdf_bytes/page_num; aquí stub con área full
                # Para real: En orquestador, pasa pdf_bytes, page_num a este método
                tables_pdf = await self._extract_tables_with_tabula(page)  # Implementa abajo
                tables.extend(
                    [{"type": "tabula", "rows": table.to_dict(orient="records"), "is_header": True, "source": "pdf"} for
                     table in tables_pdf])
            except Exception as e:
                logger.warning(f"Tabula fallback failed: {e}; usa heurística")

        logger.info(
            f"Detected {len(tables)} tables in page (text: {len(text_tables)}, tabula: {len(tables) - len(text_tables)})")
        return tables

    async def _extract_tables_with_tabula(self, page) -> List:
        """Stub: Extrae tablas con tabula (requiere pdf_bytes y page_num; ajusta en caller si needed).
        Retorna list de pandas DataFrames (rows/cols)."""
        try:
            # Para real impl: await asyncio.to_thread(tabula.read_pdf, pdf_path, pages=page_num+1, multiple_tables=True)
            # Aquí placeholder: Si no pdf_bytes, return []
            logger.info("Tabula stub: Pasa pdf_bytes/page_num desde orquestador para extraer tablas visuales")
            return []  # Expande: Integra tabula en process_pdf pasando a detector
        except Exception as e:
            logger.error(f"Tabula error: {e}")
            return []
