#!/bin/bash

# Script de verificación adaptado para el backend con Robyn

# --- Colores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║     DIAGNÓSTICO DEL BACKEND - ROBYN & POSTGRESQL         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# --- Variables ---
BACKEND_URL="http://localhost:8000"
ERRORS=0
WARNINGS=0

# --- Funciones Auxiliares ---
check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "${GREEN}✅ $1 disponible${NC}"
    else
        echo -e "${RED}❌ $1 no encontrado. Instálalo para continuar.${NC}"; ((ERRORS++));
    fi
}

check_python_package() {
    if python3 -c "import $1" &> /dev/null; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${YELLOW}⚠️  $1 no encontrado en el entorno Python actual.${NC}"; ((WARNINGS++));
    fi
}

# ═══ 1. VERIFICACIÓN DEL ENTORNO ═══
echo -e "${BLUE}═══ 1. VERIFICACIÓN DEL ENTORNO ═══${NC}"
check_command "curl"
check_command "python3"
check_command "docker"
echo ""
echo "Verificando paquetes de Python (de requirements.txt):"
check_python_package "robyn"
check_python_package "fitz" # PyMuPDF
check_python_package "sqlalchemy"
check_python_package "psycopg2"
echo -e "${YELLOW}Asegúrate de tener tu entorno virtual activado si ves advertencias.${NC}"
echo ""

# ═══ 2. VERIFICACIÓN DEL BACKEND ═══
echo -e "${BLUE}═══ 2. VERIFICACIÓN DEL BACKEND ═══${NC}"
# Verificar proceso del servidor Robyn
if pgrep -f "python run.py" > /dev/null; then
    echo -e "${GREEN}✅ Proceso del servidor ('python run.py') corriendo.${NC}"
else
    echo -e "${RED}❌ Proceso del servidor NO encontrado.${NC}"
    echo -e "${YELLOW}   → Inicia tu servidor con: python run.py${NC}"; ((ERRORS++));
fi

# Verificar puerto 8000
if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Puerto 8000 en uso (probablemente por el servidor).${NC}"
else
    echo -e "${RED}❌ El puerto 8000 está libre. ¿Está el servidor corriendo?${NC}"; ((ERRORS++));
fi

# Verificar conectividad HTTP
if curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/api/health" | grep -q "200"; then
    echo -e "${GREEN}✅ El endpoint de salud del backend responde correctamente.${NC}"
else
    echo -e "${RED}❌ El backend no responde en el endpoint de salud.${NC}"; ((ERRORS++));
fi
echo ""

# ═══ 3. PRUEBA DE SUBIDA DE ARCHIVO (UPLOAD) ═══
echo -e "${BLUE}═══ 3. PRUEBA DE SUBIDA DE ARCHIVO (UPLOAD) ═══${NC}"
echo "Creando un PDF de prueba temporal..."
# PDF simple de una página
printf "%%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj 2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj 3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Contents 4 0 R>>endobj 4 0 obj<</Length 35>>stream\nBT /F1 24 Tf 100 700 Td(Test)Tj ET\nendstream\nendobj\nxref\n0 5\n0000000000 65535 f \n0000000010 00000 n \n0000000059 00000 n \n0000000112 00000 n \n0000000194 00000 n \ntrailer<</Size 5/Root 1 0 R>>\nstartxref\n280\n%%%%EOF" > /tmp/test_upload.pdf
echo -e "${GREEN}✅ PDF de prueba creado en /tmp/test_upload.pdf${NC}"
echo ""
echo "Enviando el PDF al endpoint /api/process..."

# --- Método robusto para capturar la respuesta y el código HTTP ---
http_response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
  -X POST "$BACKEND_URL/api/process" \
  -F "file=@/tmp/test_upload.pdf")

http_body=$(echo "$http_response" | sed -e 's/HTTP_STATUS\:.*//g')
http_code=$(echo "$http_response" | tr -d '\n' | sed -e 's/.*HTTP_STATUS://')

echo -e "${MAGENTA}═══ RESULTADO DE LA PRUEBA ═══${NC}"
echo "Código de estado HTTP: $http_code"
echo "Cuerpo de la respuesta:"
echo "─────────────────────────────────────"
echo "$http_body"
echo "─────────────────────────────────────"

if [ "$http_code" = "201" ]; then
    echo -e "${GREEN}✅ ¡PRUEBA EXITOSA! El backend procesó el archivo correctamente.${NC}"
elif [ "$http_code" = "400" ]; then
    echo -e "${RED}❌ ERROR 400 (Bad Request): La petición es incorrecta.${NC}"
    echo "   El servidor dice: $http_body"; ((ERRORS++));
elif [ "$http_code" = "500" ]; then
    echo -e "${RED}❌ ERROR 500 (Internal Server Error): Hay un error en el código del backend.${NC}"
    echo "   Revisa la terminal donde corre 'python run.py' para ver el traceback completo."; ((ERRORS++));
else
    echo -e "${RED}❌ ERROR INESPERADO (Código: $http_code). Revisa si el servidor está corriendo.${NC}"; ((ERRORS++));
fi
echo ""

# ═══ 4. RESUMEN FINAL ═══
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                      RESUMEN FINAL                       ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ ¡Diagnóstico completado sin errores!${NC}"
    echo "El backend parece estar configurado y funcionando correctamente."
    echo "Si tu app de Flutter sigue fallando, el problema probablemente está en el código de Flutter (cómo construye o envía la petición)."
else
    echo -e "${RED}❌ Se encontraron $ERRORS errores críticos.${NC}"
    echo "Por favor, revisa los mensajes marcados con ❌ para solucionar los problemas."
fi
if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Se encontraron $WARNINGS advertencias. No son críticas, pero revísalas.${NC}"
fi
echo ""