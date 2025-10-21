from typing import List, Dict, Any, Optional
from pydantic import BaseModel  # Reemplaza dataclass para validación auto

class PDFPageBase(BaseModel):
    page_number: int
    text: str
    images: List[Dict[str, Any]] = []  # Imágenes por página
    width: float
    height: float

class PDFPageResponse(PDFPageBase):
    dimensions: Dict[str, float]  # Para JSON response

    class Config:
        from_attributes = True  # Para from SQLAlchemy models

class PDFDocumentBase(BaseModel):
    document_id: str
    filename: str
    total_pages: int
    pages: List[PDFPageBase]

class PDFDocumentResponse(PDFDocumentBase):
    continuous_text: Optional[str] = None  # Nuevo: Texto merged (concat pages con \n)
    global_images: Optional[List[Dict[str, Any]]] = None  # Nuevo: Imágenes ordenadas global

    class Config:
        from_attributes = True

# Utils (mismo que to_dict)
def page_to_dict(page: PDFPageBase) -> Dict[str, Any]:
    return {
        "page_number": page.page_number,
        "text": page.text,
        "images": page.images,
        "dimensions": {"width": page.width, "height": page.height}
    }

def document_to_dict(doc: PDFDocumentResponse) -> Dict[str, Any]:
    return {
        "id": doc.document_id,
        "filename": doc.filename,
        "total_pages": doc.total_pages,
        "pages": [page_to_dict(p) for p in doc.pages],
        "continuousText": doc.continuous_text,  # Si modo continuous
        "globalImages": doc.global_images
    }
