#!/bin/bash
# Completa el asistente de Jellyfin por API. Sin tocar el navegador y REPETIBLE:
# si manana rehaces el servidor, vuelves a lanzar esto y queda igual.
set -e
J=http://10.10.10.10:8096
ADMIN=luca
PASS='clave-falsa-de-lab'     # contrasena FALSA, esto es un laboratorio

# 1. idioma y pais de los metadatos
curl -s -X POST "$J/Startup/Configuration" -H 'Content-Type: application/json' \
  -d '{"UICulture":"es","MetadataCountryCode":"ES","PreferredMetadataLanguage":"es"}'

# 2. el asistente exige leer este paso antes de crear el usuario
curl -s "$J/Startup/User" >/dev/null

# 3. usuario administrador
curl -s -X POST "$J/Startup/User" -H 'Content-Type: application/json' \
  -d "{\"Name\":\"$ADMIN\",\"Password\":\"$PASS\"}"

# 4. acceso remoto SI, mapeo automatico de puertos NO (nada de UPnP abriendo
#    agujeros en tu router sin preguntarte)
curl -s -X POST "$J/Startup/RemoteAccess" -H 'Content-Type: application/json' \
  -d '{"EnableRemoteAccess":true,"EnableAutomaticPortMapping":false}'

# 5. cerrar el asistente
curl -s -X POST "$J/Startup/Complete"

echo "asistente completado: administrador '$ADMIN'"
