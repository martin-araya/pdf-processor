"""Database module - Exports models y manager con async support."""

try:
    from .connection import DatabaseManager, db_manager, get_async_db  # Singleton + deps async
    from .models import Base, Document, Page, Image  # Models para repo/ORM
except ImportError as e:
    # Temporal para dev: Si cyclic o missing, log y stub
    logger = __import__('logging').getLogger(__name__)
    logger.warning(f"Import warning en database/__init__: {e} - Chequea connection.py/models.py")
    DatabaseManager = None
    db_manager = None
    get_async_db = None
    Base = None
    Document = Page = Image = None

__all__ = ["DatabaseManager", "db_manager", "get_async_db", "Base", "Document", "Page", "Image"]
