from typing import List, Dict

def detect_tables_in_text(text: str) -> List[Dict]:
    """Detecta tablas en texto vía heurísticas (|, -, =, dígitos, o keywords como THROUGHPUT).
    Retorna lista de dicts con rows, is_header, y offset_chars aproximado (líneas * 100 chars est.)."""
    if not text or not isinstance(text, str):
        return []
    tables = []
    lines = text.split('\n')
    offset_chars = 0
    for idx, line in enumerate(lines):
        if not line.strip():
            offset_chars += 100  # Aprox por línea vacía
            continue
        line = line.strip()
        if is_table_line(line):
            rows = extract_rows(line)
            if len(rows) > 1:  # Múltiples columnas = tabla válida
                is_header = line.startswith('Table') or 'THROUGHPUT' in line.upper()
                tables.append({
                    "rows": rows,
                    "is_header": is_header,
                    "offset_chars": offset_chars  # Para posicionar en continuous/visualization
                })
        offset_chars += len(line) + 1  # + \n
    return tables

def is_table_line(line: str) -> bool:
    """Verdadero si la línea parece tabla (contiene |, -, =, dígitos puros, o keywords)."""
    if not line or not isinstance(line, str):
        return False
    return (any(char in line for char in ['|', '-', '=']) or line.strip().isdigit()) or \
           any(kw in line.upper() for kw in ['THROUGHPUT', 'LATENCY', 'ACCURACY'])

def extract_rows(line: str) -> List[str]:
    """Extrae filas/celdas: split por | o espacios múltiples (fallback para tabs)."""
    if '|' in line:
        return [cell.strip() for cell in line.split('|') if cell.strip()]
    else:
        # Fallback para líneas con espacios (e.g., tabs simulados)
        import re
        return [cell.strip() for cell in re.split(r'\s{2,}', line) if cell.strip()]
