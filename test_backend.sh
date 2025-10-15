#!/bin/bash

# Script para probar el backend y ver la respuesta exacta

echo "🧪 Probando el backend PDF Processor..."
echo ""

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Verificar que curl está instalado
if ! command -v curl &> /dev/null; then
    echo -e "${RED}❌ curl no está instalado${NC}"
    echo "Instala con: sudo apt install curl"
    exit 1
fi

# URL del backend
BACKEND_URL="http://localhost:8000"

echo -e "${YELLOW}1. Probando endpoint raíz (/)...${NC}"
response=$(curl -s -w "\n%{http_code}" "$BACKEND_URL/")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

echo "   HTTP Code: $http_code"
echo "   Response:"
echo "$body" | head -20
echo ""

echo -e "${YELLOW}2. Probando con un PDF de prueba...${NC}"

# Crear un PDF de prueba si no existe
if [ ! -f "test.pdf" ]; then
    echo "   Creando PDF de prueba..."
    # Crear un PDF mínimo de prueba
    echo "%PDF-1.4
1 0 obj
<<
/Type /Catalog
/Pages 2 0 R
>>
endobj
2 0 obj
<<
/Type /Pages
/Kids [3 0 R]
/Count 1
>>
endobj
3 0 obj
<<
/Type /Page
/Parent 2 0 R
/Resources <<
/Font <<
/F1 <<
/Type /Font
/Subtype /Type1
/BaseFont /Helvetica
>>
>>
>>
/MediaBox [0 0 612 792]
/Contents 4 0 R
>>
endobj
4 0 obj
<<
/Length 44
>>
stream
BT
/F1 12 Tf
100 700 Td
(Test PDF) Tj
ET
endstream
endobj
xref
0 5
0000000000 65535 f
0000000009 00000 n
0000000058 00000 n
0000000115 00000 n
0000000317 00000 n
trailer
<<
/Size 5
/Root 1 0 R
>>
startxref
410
%%EOF" > test.pdf
    echo "   ✅ PDF de prueba creado"
fi

echo ""
echo -e "${YELLOW}3. Subiendo PDF al backend...${NC}"
echo "   URL: $BACKEND_URL/api/process"
echo ""

# Hacer la petición y capturar TODO
response=$(curl -s -w "\n---SEPARATOR---\n%{http_code}\n%{content_type}" \
  -X POST "$BACKEND_URL/api/process" \
  -H "accept: application/json" \
  -F "file=@test.pdf" \
  2>&1)

# Separar la respuesta
body=$(echo "$response" | sed -n '1,/---SEPARATOR---/p' | sed '$d')
http_code=$(echo "$response" | grep -A1 "---SEPARATOR---" | tail -2 | head -1)
content_type=$(echo "$response" | tail -1)

echo -e "${BLUE}📊 Resultados:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "HTTP Status Code: $http_code"
echo "Content-Type: $content_type"
echo ""
echo "Response Body:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$body"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Analizar la respuesta
if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✅ Backend respondió OK (200)${NC}"

    # Verificar si es JSON válido
    if echo "$body" | jq . &> /dev/null; then
        echo -e "${GREEN}✅ La respuesta es JSON válido${NC}"
        echo ""
        echo "JSON formateado:"
        echo "$body" | jq .
    else
        echo -e "${RED}❌ La respuesta NO es JSON válido${NC}"
        echo ""
        echo "Primeros 500 caracteres de la respuesta:"
        echo "$body" | head -c 500
        echo ""
        echo ""
        echo "⚠️  PROBLEMA: El backend está respondiendo 200 OK pero con JSON inválido"
        echo "   Esto sugiere un error en el código del backend al formatear la respuesta"
    fi
elif [ "$http_code" = "400" ]; then
    echo -e "${RED}❌ Error 400: Bad Request${NC}"
    echo "   El backend rechazó la solicitud"
    echo "   Revisa el formato de la petición"
elif [ "$http_code" = "500" ]; then
    echo -e "${RED}❌ Error 500: Internal Server Error${NC}"
    echo "   Hay un error en el código del backend"
    echo "   Revisa los logs del servidor"
else
    echo -e "${RED}❌ Error inesperado: $http_code${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}📝 Siguientes pasos:${NC}"
echo ""

if [ "$http_code" = "200" ] && ! echo "$body" | jq . &> /dev/null; then
    echo "El backend responde pero el JSON es inválido."
    echo ""
    echo "Posibles causas:"
    echo "  1. El backend está devolviendo texto plano en lugar de JSON"
    echo "  2. El backend está devolviendo JSON mal formado"
    echo "  3. Hay caracteres especiales no escapados"
    echo ""
    echo "Soluciones:"
    echo "  1. Revisa los logs del backend (terminal donde corre uvicorn)"
    echo "  2. Verifica que el endpoint retorne JSON válido:"
    echo "     return JSONResponse(content={...})"
    echo "  3. Prueba en Swagger: http://localhost:8000/docs"
fi

echo ""
echo "💡 Tip: Mira los logs del backend para más detalles"
echo "   (En la terminal donde está corriendo uvicorn)"