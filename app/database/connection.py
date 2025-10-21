import asyncio  # Fix: Para await asyncio.sleep
import logging
import time
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import event, exc
from sqlalchemy.pool import StaticPool  # Fix: StaticPool para async engine (simple, no queue issues)
from app.config import PostgresConfig  # Asume get_connection_string async-friendly

# Importa models para metadata (ahora existe)
from .models import Base  # Base para create_all

logger = logging.getLogger(__name__)


class DatabaseManager:
    _instance = None
    _engine = None
    _async_session_factory = None
    _initialized = False  # Flag para async init

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(DatabaseManager, cls).__new__(cls)
        return cls._instance

    def __init__(self, retries=5, delay=3):
        if self._engine is not None:
            return  # Ya init partial

        # Crea engine básico sync (sin test; async en initialize)
        async_connection_string = PostgresConfig.get_connection_string(async_mode=True)
        logger.info("🔧 Creando async engine (test pendiente)...")
        self._engine = create_async_engine(
            async_connection_string,
            poolclass=StaticPool,  # Fix: StaticPool recomendado para async (simple, no connections reuse issues)
            pool_pre_ping=True,  # Verifica conns en Docker (ping en acquire)
            pool_recycle=300,  # Anti-stale connections
            echo=False  # Logs SQL off; set True en dev si needed
        )
        logger.info("✅ Async engine creado (sync parte)")

    async def initialize(self, retries=5, delay=3) -> None:
        """Fix Principal: Async init con test, factory y create tables. Llama en startup."""
        if self._initialized:
            return

        for attempt in range(retries):
            try:
                logger.info(f"(Intento {attempt + 1}/{retries}) Testeando conexión async a Postgres...")
                # Fix: async with ahora en async def
                async with self._engine.begin() as conn:  # Línea ~42: OK aquí (async context)
                    # Simple ping (conn existe → OK)
                    pass

                # Crea session factory post-test
                self._async_session_factory = sessionmaker(
                    self._engine, class_=AsyncSession, expire_on_commit=False
                )

                # Crea tablas async-safe
                async with self._engine.begin() as conn:
                    await conn.run_sync(Base.metadata.create_all)  # Sync create en async conn

                self._initialized = True
                logger.info("✅ Inicialización async completa: Factory + tablas creadas")
                return

            except exc.OperationalError as e:
                logger.warning(f"⚠️ Error async al conectar (DB no lista?). Reintentando en {delay}s...: {e}")
                if attempt + 1 == retries:
                    logger.error(f"❌ Fallo async después de {retries} intentos: {e}")
                    raise
                await asyncio.sleep(delay)  # Fix: Ahora resuelto con import
            except Exception as e:
                logger.error(f"❌ Error inesperado en init async: {e}", exc_info=True)
                raise

    async def get_async_session(self) -> AsyncSession:
        """Async getter para session; await init si needed."""
        if not self._initialized:
            await self.initialize()
        if not self._async_session_factory:
            raise Exception("Async session factory no inicializada. Init fallida?")
        return self._async_session_factory()

    async def close(self):
        if self._engine:
            await self._engine.dispose()
            logger.info("🔒 Async engine disposed")

# Global singleton
db_manager = DatabaseManager()

# Fix: Define get_async_db aquí (global dep para FastAPI; yield session)
async def get_async_db() -> AsyncSession:
    session = await db_manager.get_async_session()
    try:
        yield session
    finally:
        await session.close()
