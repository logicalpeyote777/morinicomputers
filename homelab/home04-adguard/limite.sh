#!/bin/bash
# Cambia SOLO el limite de consultas por segundo y por cliente (0 = sin limite).
# Ojo: /control/dns_config REEMPLAZA la configuracion entera, asi que hay que
# leerla, tocar el campo y devolverla completa. Mandar solo {"ratelimit":N}
# te resetea el upstream, el modo de bloqueo y la cache a los valores de fabrica.
set -u
A=(-sS -u homelab:clave-falsa-de-laboratorio -H "Content-Type: application/json")
AGH=http://10.10.10.10:8090
curl "${A[@]}" "$AGH/control/dns_info" \
  | jq ".ratelimit = ${1:-0}" \
  | curl "${A[@]}" -X POST "$AGH/control/dns_config" -d @- >/dev/null
echo -n "  ratelimit = "
curl -s -u homelab:clave-falsa-de-laboratorio "$AGH/control/dns_info" | jq -r .ratelimit
