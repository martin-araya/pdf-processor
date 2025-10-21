from sqlalchemy import Column, Integer, String, Text, LargeBinary, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import declarative_base, relationship
from sqlalchemy.sql import func
from typing import List

Base = declarative_base()

class Document(Base):
    __tablename__ = "documents"

    id = Column(String, primary_key=True, index=True)
    filename = Column(String, nullable=False)
    total_pages = Column(Integer, nullable=False)
    is_translation = Column(Boolean, default=False)
    original_document_id = Column(String, ForeignKey("documents.id"), nullable=True)
    target_language = Column(String, nullable=True)
    continuous_text = Column(Text, nullable=True)  # Opcional, para mode=continuous
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    pages = relationship("Page", back_populates="document", cascade="all, delete-orphan")
    original = relationship("Document", remote_side=[id], back_populates="translations")  # Self-ref para originals
    translations = relationship("Document", back_populates="original", foreign_keys=[original_document_id])

class Page(Base):
    __tablename__ = "pages"

    id = Column(String, primary_key=True, index=True)
    document_id = Column(String, ForeignKey("documents.id"), nullable=False, index=True)
    page_number = Column(Integer, nullable=False)
    text = Column(Text, nullable=True)  # OCR/extracted text
    width = Column(Integer, nullable=False)  # Dimensions
    height = Column(Integer, nullable=False)

    # Relationships
    document = relationship("Document", back_populates="pages")
    images = relationship("Image", back_populates="page", cascade="all, delete-orphan")

class Image(Base):
    __tablename__ = "images"

    id = Column(String, primary_key=True, index=True)
    page_id = Column(String, ForeignKey("pages.id"), nullable=False, index=True)
    image_data = Column(LargeBinary, nullable=False)  # Base64 decoded bytes
    extension = Column(String(10), nullable=False, default="png")  # png, jpg, etc.

    # Relationships
    page = relationship("Page", back_populates="images")
