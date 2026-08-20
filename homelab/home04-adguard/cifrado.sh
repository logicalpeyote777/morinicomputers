#!/bin/bash
# ?Por donde sale de verdad la consulta que AdGuard no tiene en cache?
set -u
dig +short @10.10.10.10 "n$RANDOM.debian.org" A >/dev/null 2>&1
sleep 1
echo -n "  upstream usado: "
curl -s -u homelab:clave-falsa-de-laboratorio "http://10.10.10.10:8090/control/querylog?limit=1" \
| jq -r '.data[0].upstream'
echo "  (tls:// = cifrado. Tu operadora ve una conexion, no QUE has preguntado)"
