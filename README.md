# PDF Processor Flutter App

## Descripción General

La aplicación PDF Processor es una herramienta completa construida con Flutter que permite a los usuarios subir, procesar, ver y traducir documentos PDF. La aplicación está diseñada para funcionar con dos servicios de backend: un backend de autenticación de Go y un backend de procesamiento de documentos de Java.

## Funcionalidades

- **Autenticación de Usuarios:** Sistema seguro de registro e inicio de sesión de usuarios.
- **Carga de PDF:** Sube archivos PDF desde tu dispositivo.
- **Procesamiento de Documentos:** Extrae texto, imágenes y tablas de los PDF.
- **Visualización de Documentos:** Visualizador de PDF interactivo con múltiples modos:
    - **Visor Paginado:** Muestra el documento página por página.
    - **Visor Continuo:** Muestra el documento en un scroll infinito.
    - **Modo de Visualización:** Muestra el contenido extraído (texto, imágenes, tablas) de una manera estructurada.
- **Búsqueda en Documentos:** Busca texto dentro del contenido del PDF.
- **Traducción de Documentos:** Traduce el texto del documento a varios idiomas.
- **Gestión de Documentos:** Visualiza, gestiona y elimina tus documentos subidos.
- **Tema Oscuro/Claro:** Cambia entre los modos de tema oscuro y claro.

## Estructura del Proyecto

El proyecto sigue una arquitectura limpia y organizada, separando las responsabilidades en diferentes capas:

```
lib/
├── core/
│   ├── network/
│   │   └── dio_client.dart       # Configuración de Dio con interceptores para la comunicación con la API
│   └── providers/
│       ├── auth_provider.dart    # Gestión del estado de autenticación con Riverpod
│       └── theme_provider.dart   # Gestión del estado del tema con Riverpod
├── models/
│   └── document.dart           # Modelos de datos para Document, PageData, ImageData, etc.
├── screens/
│   ├── auth_screen.dart        # Pantalla de inicio de sesión y registro
│   ├── dashboard_screen.dart   # Panel de control principal para listar y gestionar documentos
│   ├── document_screen.dart    # Pantalla de visualización de documentos con múltiples modos
│   ├── home_screen.dart        # Pantalla de inicio después de iniciar sesión, con el cargador de PDF
│   └── welcome_screen.dart     # Pantalla de bienvenida después de un inicio de sesión exitoso
├── services/
│   ├── api_base.dart           # Configuración base de la API, instancias de Dio y gestión de tokens
│   ├── auth_service.dart       # Servicio para la comunicación con el backend de autenticación de Go
│   └── document_service.dart   # Servicio para la comunicación con el backend de documentos de Java
├── widgets/
│   ├── document_app_bar.dart   # AppBar para la pantalla de visualización de documentos
│   ├── document_viewer.dart    # Widget principal para la visualización de documentos
│   ├── image_gallery.dart      # Galería para mostrar las imágenes extraídas
│   ├── page_card.dart          # Widget para mostrar el contenido de una sola página
│   ├── pdf_uploader.dart       # Widget para subir archivos PDF
│   └── ...                     # Otros widgets reutilizables
└── main.dart                   # Punto de entrada de la aplicación, configuración de rutas y proveedores
```

## Pantallas de la Aplicación

La aplicación consta de las siguientes pantallas:

1.  **AuthScreen:** Permite a los usuarios registrarse e iniciar sesión.
2.  **HomeScreen:** La pantalla principal después de iniciar sesión, donde los usuarios pueden subir un PDF.
3.  **WelcomeScreen:** Una pantalla de bienvenida que se muestra después de un inicio de sesión exitoso.
4.  **DashboardScreen:** Muestra una lista de todos los documentos subidos por el usuario, permitiéndole gestionarlos.
5.  **DocumentScreen:** La pantalla principal para ver un documento. Incluye un visor de PDF, así como modos para ver el texto, las imágenes y las tablas extraídas.

## Comunicación con la API

La aplicación se comunica con dos servicios de backend:

### Backend de Autenticación (Go)

-   **URL Base:** `http://<host>:9001`
-   **Endpoints:**
    -   `POST /auth/login`: Inicia sesión de un usuario.
    -   `POST /auth/register`: Registra un nuevo usuario.
    -   `GET /auth/validate`: Valida el token de autenticación actual.
    -   `POST /auth/refresh`: Refresca un token de autenticación caducado.

### Backend de Documentos (Java)

-   **URL Base:** `http://<host>:8080/api`
-   **Endpoints:**
    -   `POST /documents`: Sube un nuevo documento PDF.
    -   `GET /documents`: Lista todos los documentos del usuario.
    -   `GET /documents/{id}`: Obtiene los detalles de un documento específico.
    -   `DELETE /documents/{id}`: Elimina un documento.
    -   `POST /documents/{id}/translate`: Traduce el contenido de un documento.
    -   `GET /documents/{id}/pdf`: Obtiene el archivo PDF binario.
    -   `GET /documents/{id}/images/{imageId}`: Obtiene los datos de una imagen específica.

## Gestión de Estado

La aplicación utiliza **Flutter Riverpod** para la gestión del estado. Los proveedores se utilizan para gestionar el estado de la autenticación, el estado del tema y para inyectar dependencias como los servicios de la API.

## Cómo Empezar

1.  **Clona el repositorio:**
    ```sh
    git clone https://github.com/martin-araya/pdf-processor.git
    ```
2.  **Instala las dependencias:**
    ```sh
    flutter pub get
    ```
3.  **Ejecuta la aplicación:**
    ```sh
    flutter run
    ```

Asegúrate de que los servicios de backend de Go y Java se estén ejecutando y sean accesibles desde la aplicación. Las URLs base de la API se pueden configurar en `lib/services/api_base.dart`.
