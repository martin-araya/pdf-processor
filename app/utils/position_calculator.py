from typing import Dict, Any


def calculate_relative_position(bounds: Dict[str, Any], page_width: int, page_height: int) -> Dict[str, float]:
    """Calcula posición y tamaño relativos de imagen en % (basado en bounds pixels vs. dimensiones página).
    Usa defaults (center 50% x/y, 20-15% size) si bounds incompleto."""
    if not bounds or not isinstance(bounds, dict):
        # Placeholder center
        return {"x": 50.0, "y": 30.0, "width": 20.0, "height": 15.0}

    x = (bounds.get('x', page_width // 4) / page_width * 100) if page_width > 0 else 50.0
    y = (bounds.get('y', page_height // 4) / page_height * 100) if page_height > 0 else 30.0
    rel_width = (bounds.get('width', 200) / page_width * 100) if page_width > 0 else 20.0
    rel_height = (bounds.get('height', 150) / page_height * 100) if page_height > 0 else 15.0

    return {"x": max(0, min(100, x)), "y": max(0, min(100, y)), "width": max(5, min(100, rel_width)),
            "height": max(5, min(100, rel_height))}


def calculate_continuous_position(page_offset: int, char_offset: int = 0) -> Dict[str, Any]:
    """Para modo continuous: posición basada en offset chars (para insertar img post-texto).
    Retorna page_offset y relative_pos placeholder."""
    return {
        "page_offset": page_offset,
        "relative_pos": calculate_relative_position({}, 1000, 1000)  # Default % si no bounds
    }
