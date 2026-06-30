#!/bin/bash
# iso-fetch.sh — baja una ISO a un almacenamiento de Proxmox y VERIFICA su checksum.
#
# Usa la propia API de Proxmox (download-url): la imagen se descarga EN el servidor
# (rápido) y, si le pasas el SHA256, Proxmox la verifica por ti antes de aceptarla.
# Así nunca instalas un sistema desde una imagen corrupta o manipulada.
#
#   iso-fetch.sh <storage> <url> [sha256]
#   ej: iso-fetch.sh local https://dl-cdn.alpinelinux.org/.../alpine-virt-3.24.1-x86_64.iso e73a62...
#
# El <storage> debe tener el contenido 'iso' activado (local, un dir...). Un lvm-thin NO sirve.
set -euo pipefail

STORAGE="${1:?uso: iso-fetch.sh <storage> <url> [sha256]}"
URL="${2:?falta la URL de la ISO}"
SHA="${3:-}"
NODE="$(hostname)"
FILE="$(basename "$URL")"

echo ">> Descargando '$FILE' a '$STORAGE' vía la API de Proxmox (download-url)..."
if [ -n "$SHA" ]; then
  pvesh create "/nodes/$NODE/storage/$STORAGE/download-url" \
    --content iso --url "$URL" --filename "$FILE" \
    --checksum-algorithm sha256 --checksum "$SHA"
else
  echo "   AVISO: sin checksum -> se baja SIN verificar. Pásale el SHA256 siempre que puedas."
  pvesh create "/nodes/$NODE/storage/$STORAGE/download-url" \
    --content iso --url "$URL" --filename "$FILE"
fi

echo ">> Hecho. ISOs disponibles en '$STORAGE':"
pvesm list "$STORAGE" --content iso
