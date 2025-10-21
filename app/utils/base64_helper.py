import base64
from urllib.parse import urlparse
from typing import Optional

def safe_decode_base64(data_uri: str) -> Optional[bytes]:
    """Decodifica base64 desde data URI (extrae post-comma; maneja prefix data: de forma segura)."""
    if not data_uri or not isinstance(data_uri, str):
        return None
    if data_uri.startswith("data:"):
        # Extrae el payload base64 post-comma
        parsed = urlparse(data_uri)
        if ',' in parsed.path:
            payload = parsed.path.split(",", 1)[1]
        else:
            return None
    else:
        payload = data_uri
    try:
        return base64.b64decode(payload)
    except Exception:
        return None

def encode_to_data_uri(img_bytes: bytes, extension: str = "png") -> str:
    """Codifica bytes a data URI (e.g., data:image/png;base64,...)."""
    if not img_bytes:
        return ""
    b64 = base64.b64encode(img_bytes).decode('utf-8')
    return f"data:image/{extension};base64,{b64}"
