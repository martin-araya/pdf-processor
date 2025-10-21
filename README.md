# Microservicio de Procesamiento de PDF

Este es un microservicio backend construido con FastAPI diseñado para procesar, almacenar y traducir documentos PDF. La aplicación extrae texto e imágenes de las páginas de un PDF, lo guarda en una base de datos y ofrece la posibilidad de traducir el contenido a múltiples idiomas.

## ✨ Características Principales

- **Procesamiento de PDF**: Extrae texto e imágenes de archivos PDF.
- **API Asíncrona**: Construido con FastAPI y Uvicorn para un alto rendimiento.
- **Almacenamiento de Documentos**: Guarda los documentos procesados y sus traducciones en una base de datos para futuras consultas.
- **Traducción de Texto**: Integra un servicio de traducción para convertir el texto extraído a diferentes idiomas.
- **Documentación Automática**: Genera documentación interactiva de la API a través de Swagger UI y ReDoc.
- **Configuración Flexible**: Utiliza variables de entorno para una configuración sencilla en diferentes entornos (desarrollo, producción).

## 🛠️ Tecnologías Utilizadas

- **Backend**: Python 3
- **Framework**: FastAPI
- **Servidor ASGI**: Uvicorn
- **Procesamiento de PDF**: PyMuPDF (`fitz`)
- **Traducción**: `deep-translator`
- **Base de Datos**: SQLAlchemy (con soporte asíncrono)
- **Variables de Entorno**: `python-dotenv`

## 🚀 Instalación y Configuración

Sigue estos pasos para poner en marcha el servidor localmente.

### 1. Prerrequisitos

- Python 3.10 o superior
- `pip` (gestor de paquetes de Python)

### 2. Clonar el Repositorio

```bash
git clone <URL-DEL-REPOSITORIO>
cd backend/microservicios/proceso-pdf
```

### 3. Crear un Entorno Virtual

Es una buena práctica aislar las dependencias del proyecto.

```bash
# Crear el entorno virtual
python -m venv venv

# Activar el entorno (en Linux/macOS)
source venv/bin/activate

# En Windows
# venv\Scripts\activate
```

### 4. Instalar Dependencias

Instala todas las librerías necesarias desde el archivo `requirements.txt`.

```bash
pip install -r requirements.txt
```

### 5. Configurar Variables de Entorno

Crea un archivo llamado `.env` en la raíz del proyecto (`proceso-pdf/`) y añade las siguientes variables. Este archivo es fundamental para configurar la conexión a la base de datos y otros parámetros de la aplicación.

```env
# --- Configuración del Servidor ---
HOST=0.0.0.0
PORT=8000
LOG_LEVEL=INFO

# --- Configuración de la Base de Datos (Ejemplo con PostgreSQL asíncrono) ---
DB_USER=tu_usuario_db
DB_PASSWORD=tu_contraseña_db
DB_HOST=localhost
DB_PORT=5432
DB_NAME=lector_pdf_db
DB_URL=postgresql+asyncpg://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}

# --- Configuración de CORS (si es necesario) ---
# ALLOWED_ORIGINS=["http://localhost:3000","http://localhost:8080"]
```

**Nota**: Asegúrate de que la base de datos (`lector_pdf_db` en el ejemplo) exista en tu servidor de base de datos.

## ▶️ Cómo Ejecutar la Aplicación

Una vez que hayas configurado tu entorno, puedes iniciar el servidor desde el directorio raíz (`proceso-pdf/`) con el siguiente comando:

```bash
uvicorn app.main:app --reload
```

- `uvicorn`: Es el servidor ASGI que ejecuta la aplicación.
- `app.main:app`: Le indica a Uvicorn que busque el objeto `app` (la instancia de FastAPI) en el archivo `main.py` dentro del directorio `app`.
- `--reload`: Activa la recarga automática del servidor cada vez que se detecta un cambio en el código.

El servidor estará disponible en `http://localhost:8000`.

## 📚 Guía de la API

La API proporciona endpoints para procesar, consultar y gestionar documentos.

### Documentación Interactiva

Una vez que el servidor esté en ejecución, puedes acceder a la documentación interactiva de Swagger UI para probar los endpoints directamente desde tu navegador:

- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

### Endpoints

#### 1. Procesar un nuevo PDF

Sube un archivo PDF para que sea procesado y almacenado.

- **Endpoint**: `POST /api/process/`
- **Descripción**: Recibe un archivo PDF, extrae su contenido y lo guarda.
- **Formato**: `multipart/form-data`

**Ejemplo con `curl`**:

```bash
curl -X POST "http://localhost:8000/api/process/" \
     -F "file=@/ruta/a/tu/documento.pdf"
```

**Respuesta Exitosa (Código 201)**:

```json
{
  "id": "a1b2c3d4-e5f6-7890-1234-567890abcdef",
  "filename": "documento.pdf",
  "total_pages": 10,
  "message": "PDF procesado y guardado exitosamente",
  "status": "success"
}
```

#### 2. Obtener un Documento Procesado

Recupera la información de un documento previamente procesado usando su ID.

- **Endpoint**: `GET /api/process/{doc_id}`
- **Parámetros de Ruta**:
  - `doc_id` (string): El ID único del documento.
- **Parámetros de Query**:
  - `mode` (string, opcional): `'paged'` (default) o `'continuous'` para obtener el texto completo.
  - `include_images` (bool, opcional): `true` para incluir los datos de las imágenes en base64.

**Ejemplo con `curl`**:

```bash
curl -X GET "http://localhost:8000/api/process/a1b2c3d4-e5f6-7890-1234-567890abcdef"
```

#### 3. Traducir un Documento

Traduce el texto de un documento existente a otro idioma.

- **Endpoint**: `POST /api/process/{doc_id}/translate`
- **Parámetros de Ruta**:
  - `doc_id` (string): El ID del documento a traducir.
- **Cuerpo de la Petición** (`application/json`):
  - `target_lang` (string): Código del idioma de destino (ej: `en`, `es`, `fr`).
  - `source_lang` (string, opcional): Código del idioma de origen. Por defecto es `auto`.

**Ejemplo con `curl`**:

```bash
curl -X POST "http://localhost:8000/api/process/a1b2c3d4-e5f6-7890-1234-567890abcdef/translate" \
     -H "Content-Type: application/json" \
     -d '{"target_lang": "en"}'
```

**Respuesta**: Devuelve la estructura completa del documento con el texto traducido.

#### 4. Eliminar un Documento

Borra un documento y todas sus traducciones asociadas de la base de datos.

- **Endpoint**: `DELETE /api/process/{doc_id}`
- **Parámetros de Ruta**:
  - `doc_id` (string): El ID del documento a eliminar.

**Ejemplo con `curl`**:

```bash
curl -X DELETE "http://localhost:8000/api/process/a1b2c3d4-e5f6-7890-1234-567890abcdef"
```

**Respuesta Exitosa (Código 200)**:

```json
{
  "message": "Documento eliminado",
  "id": "a1b2c3d4-e5f6-7890-1234-567890abcdef",
  "status": "success"
}
```

#### 5. Health Check

Verifica el estado de la aplicación.

- **Endpoint**: `GET /api/health`

**Ejemplo con `curl`**:

```bash
curl -X GET "http://localhost:8000/api/health"
```

**Respuesta**:

```json
{
  "status": "ok"
}
```

## 📂 Estructura del Proyecto

```
proceso-pdf/
├── app/
│   ├── database/         # Configuración de DB (conexión, modelos)
│   ├── repositories/     # Lógica de acceso a datos (CRUD)
│   ├── routes/           # Endpoints de la API (FastAPI routers)
│   ├── services/         # Lógica de negocio (procesamiento, traducción)
│   ├── __init__.py
│   ├── config.py         # Carga de configuración
│   └── main.py           # Punto de entrada de la aplicación FastAPI
├── .env                  # (No versionado) Variables de entorno
├── requirements.txt      # Dependencias de Python
└── README.md             # Este archivo
```
