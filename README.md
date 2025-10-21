# 🔐 Auth-Service: Microservicio de Autenticación en Go

Este es un microservicio de autenticación robusto y escalable, desarrollado en Go, que proporciona funcionalidades esenciales de registro, inicio de sesión, validación y refresco de tokens JWT. Está diseñado para ser utilizado por aplicaciones frontend (como Flutter) y otros microservicios, asegurando una gestión segura de usuarios y sesiones.

## ✨ Características Principales

*   **Registro de Usuarios**: Permite a nuevos usuarios crear una cuenta con email y contraseña.
*   **Inicio de Sesión**: Autentica a los usuarios existentes y emite un JSON Web Token (JWT) para futuras solicitudes.
*   **Validación de Token**: Verifica la validez de un JWT, confirmando la identidad del usuario y la vigencia de la sesión.
*   **Refresco de Token**: Permite renovar un token JWT antes de que expire, mejorando la experiencia de usuario y la seguridad.
*   **Cifrado de Contraseñas**: Utiliza `bcrypt` para almacenar contraseñas de forma segura (hashing).
*   **Base de Datos PostgreSQL**: Persistencia de datos de usuario con GORM.
*   **API RESTful**: Interfaz clara y estándar para la comunicación.
*   **Contenedorización**: Soporte para Docker y Docker Compose para un despliegue sencillo.
*   **CORS Configurable**: Configuración flexible para integración con diferentes clientes.

## 🚀 Tecnologías Utilizadas

*   **Go**: Lenguaje de programación principal.
*   **Gin Web Framework**: Framework HTTP de alto rendimiento para construir la API.
*   **GORM**: ORM (Object-Relational Mapper) para Go, facilitando la interacción con la base de datos.
*   **PostgreSQL**: Base de datos relacional para almacenar la información de los usuarios.
*   **JWT (JSON Web Tokens)**: Estándar para la creación de tokens de acceso seguros.
*   **Bcrypt**: Librería para el hashing seguro de contraseñas.
*   **Docker / Docker Compose**: Para la gestión de entornos de desarrollo y producción.

## 📦 Estructura del Proyecto

```
.
├── Dockerfile                  # Define la imagen Docker del servicio
├── docker-compose.yml          # Orquesta el servicio con PostgreSQL
├── go.mod                      # Módulos de Go y dependencias
├── go.sum                      # Sumas de verificación de dependencias
├── main.go                     # Lógica principal del microservicio (handlers, rutas, DB)
├── .env                        # Variables de entorno (ej. JWT_SECRET, DB_URL)
├── cmd/                        # (Opcional) Contiene el punto de entrada de la aplicación
├── config/                     # (Opcional) Archivos de configuración
└── internal/                   # (Opcional) Lógica interna no exportada
```

## ⚙️ Configuración y Variables de Entorno

El servicio utiliza las siguientes variables de entorno:

*   `JWT_SECRET`: **¡CRÍTICO!** Clave secreta utilizada para firmar y verificar los JWTs. **Debe ser una cadena larga y aleatoria en producción.** Si no se establece, se usa un valor por defecto (con advertencia).
*   `DB_URL`: Cadena de conexión a la base de datos PostgreSQL. Ejemplo: `host=localhost user=postgres password=postgres dbname=auth_db port=5433 sslmode=disable TimeZone=UTC`. Si no se establece, se usa un valor por defecto.

Puedes crear un archivo `.env` en la raíz del proyecto para definir estas variables:

```
JWT_SECRET="tu-super-secreto-jwt-key-segura-y-larga"
DB_URL="host=db user=postgres password=postgres dbname=auth_db port=5432 sslmode=disable TimeZone=UTC"
```
*(Nota: En el `docker-compose.yml` se suele referenciar el servicio de base de datos por su nombre de servicio, ej. `db` en lugar de `localhost`)*

## 🛠️ Instalación y Ejecución

### Prerrequisitos

*   [Go](https://golang.org/doc/install) (versión 1.18 o superior)
*   [Docker](https://docs.docker.com/get-docker/) y [Docker Compose](https://docs.docker.com/compose/install/) (recomendado para desarrollo y producción)
*   [PostgreSQL](https://www.postgresql.org/download/) (si no usas Docker Compose)

### 🐳 Con Docker Compose (Recomendado)

La forma más sencilla de levantar el servicio junto con su base de datos PostgreSQL es usando Docker Compose:

1.  **Clona el repositorio** (si aún no lo has hecho).
2.  **Crea un archivo `.env`** en la raíz del proyecto con tus variables de entorno (ver sección anterior).
3.  **Levanta los servicios**:
    ```bash
    docker-compose up --build
    ```
    Esto construirá la imagen de Go, creará un contenedor para PostgreSQL y otro para el servicio de autenticación, y los conectará.

El servicio estará disponible en `http://localhost:9001`.

### 🏃 Ejecución Local (sin Docker Compose para el servicio)

1.  **Asegúrate de tener PostgreSQL corriendo** y accesible en la `DB_URL` configurada.
2.  **Instala las dependencias de Go**:
    ```bash
    go mod tidy
    ```
3.  **Establece las variables de entorno**:
    ```bash
    export JWT_SECRET="tu-super-secreto-jwt-key-segura-y-larga"
    export DB_URL="host=localhost user=postgres password=postgres dbname=auth_db port=5433 sslmode=disable TimeZone=UTC"
    ```
    *(Ajusta `DB_URL` según tu configuración local de PostgreSQL)*
4.  **Ejecuta el servicio**:
    ```bash
    go run main.go
    ```
    El servicio se iniciará en el puerto `9001`.

## 📖 API Endpoints

Todos los endpoints están bajo el prefijo `/auth`.

### 1. `POST /auth/register`

Registra un nuevo usuario en el sistema. Si el registro es exitoso, devuelve un token JWT para el inicio de sesión automático.

*   **Request Body**: `application/json`
    ```json
    {
        "email": "usuario@example.com",
        "password": "password123"
    }
    ```
*   **Response (201 Created)**: `application/json`
    ```json
    {
        "user_id": 1,
        "username": "usuario@example.com",
        "token": "eyJhbGciOiJIUzI1Ni..."
    }
    ```
*   **Errores**:
    *   `400 Bad Request`: Datos inválidos (ej. email no válido, contraseña < 6 caracteres).
    *   `409 Conflict`: El usuario ya existe.
    *   `500 Internal Server Error`: Error interno del servidor.

### 2. `POST /auth/login`

Autentica a un usuario existente y devuelve un token JWT.

*   **Request Body**: `application/json`
    ```json
    {
        "email": "usuario@example.com",
        "password": "password123"
    }
    ```
*   **Response (200 OK)**: `application/json`
    ```json
    {
        "token": "eyJhbGciOiJIUzI1Ni...",
        "user_id": 1,
        "username": "usuario@example.com"
    }
    ```
*   **Errores**:
    *   `400 Bad Request`: Datos inválidos.
    *   `401 Unauthorized`: Usuario o contraseña inválidos.
    *   `500 Internal Server Error`: Error interno del servidor.

### 3. `GET /auth/validate`

Valida un token JWT proporcionado en el encabezado `Authorization`.

*   **Request Headers**:
    ```
    Authorization: Bearer <your_jwt_token>
    ```
*   **Response (200 OK)**: `application/json`
    ```json
    {
        "valid": true,
        "user_id": 1,
        "username": "usuario@example.com"
    }
    ```
*   **Errores**:
    *   `401 Unauthorized`: Token inválido, expirado o ausente.

### 4. `POST /auth/refresh`

Refresca un token JWT existente, emitiendo uno nuevo si el token original es válido y no ha expirado por completo.

*   **Request Body**: `application/json`
    ```json
    {
        "token": "eyJhbGciOiJIUzI1Ni..."
    }
    ```
*   **Response (200 OK)**: `application/json`
    ```json
    {
        "token": "eyJhbGciOiJIUzI1Ni...",
        "username": "usuario@example.com"
    }
    ```
*   **Errores**:
    *   `400 Bad Request`: Datos inválidos.
    *   `401 Unauthorized`: Token inválido o expirado.
    *   `500 Internal Server Error`: Error interno del servidor.

### 5. `GET /health`

Endpoint simple para verificar el estado del servicio.

*   **Response (200 OK)**: `application/json`
    ```json
    {
        "status": "Auth service running on :9001"
    }
    ```

## 👤 Modelo de Datos (User)

El servicio utiliza un modelo `User` simple para almacenar la información de los usuarios en la base de datos PostgreSQL.

```go
type User struct {
	ID       uint   `gorm:"primaryKey" json:"user_id"`
	Email    string `gorm:"unique;not null" json:"email"`
	Password string `json:"-"` // Almacena el hash de la contraseña, no se expone en JSON
}
```

*   `ID`: Identificador único del usuario (clave primaria).
*   `Email`: Correo electrónico del usuario, debe ser único y no nulo.
*   `Password`: Hash de la contraseña del usuario (nunca la contraseña en texto plano).

## 🔒 Seguridad

*   **Hashing de Contraseñas**: Se utiliza `bcrypt` para almacenar las contraseñas de forma segura.
*   **JWT**: Los tokens son firmados con una clave secreta (`JWT_SECRET`). Es crucial mantener esta clave segura y no exponerla.
*   **CORS**: Configurado para permitir solicitudes desde orígenes específicos. En producción, se recomienda restringir `AllowOrigins` a los dominios de tu aplicación.

## 🧪 Usuario de Demostración

Al iniciar el servicio por primera vez, si no existe ningún usuario con el email `test@example.com`, se creará automáticamente un usuario de demostración:

*   **Email**: `test@example.com`
*   **Contraseña**: `password123`

Esto es útil para pruebas rápidas en entornos de desarrollo. **¡No uses este usuario en producción!**

## 🌐 Configuración CORS

El servicio está configurado para permitir solicitudes CORS desde:
*   `*` (todos los orígenes - **solo para desarrollo**)
*   `http://localhost:*`
*   `http://10.0.2.2:*` (para emuladores de Android)

**Para entornos de producción, es IMPRESCINDIBLE restringir `AllowOrigins` a los dominios específicos de tu aplicación frontend.**

## 🤝 Contribución

Si deseas contribuir a este proyecto, por favor, sigue estos pasos:

1.  Haz un fork del repositorio.
2.  Crea una nueva rama (`git checkout -b feature/nueva-funcionalidad`).
3.  Realiza tus cambios y commitea (`git commit -am 'feat: Agrega nueva funcionalidad X'`).
4.  Sube tus cambios a tu fork (`git push origin feature/nueva-funcionalidad`).
5.  Abre un Pull Request.

## 📄 Licencia

Este proyecto está bajo la licencia [MIT](LICENSE).
