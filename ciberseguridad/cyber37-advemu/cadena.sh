#!/bin/bash
# cadena.sh - lanza en Caldera la emulacion del adversario contra el servidor de la empresa y
# va enseniando, accion por accion, la tecnica MITRE ATT&CK que ejecuta y su salida REAL.
# Uso: ./cadena.sh            github.com/logicalpeyote777/morinicomputers
set -u
C=http://10.13.37.10:8899                                 # Caldera (maquina atacante)
K="KEY: ADMIN123"                                         # clave de la API
ADV=bb000000-0000-4000-8000-000000000001                  # adversario "Intrusion tipica en una PYME"
PLA=aaa7c857-37a0-4c4a-85f7-4e9f7f30e31a                  # planificador atomic: una accion tras otra
SRC=ed32b9c3-9593-4c33-b0db-e2007315096b                  # hechos basicos

OP=$(curl -s -X POST -H "$K" -H 'Content-Type: application/json' "$C/api/v2/operations" -d "{
  \"name\": \"emulacion-pyme-$(date +%H%M%S)\",
  \"adversary\": {\"adversary_id\": \"$ADV\"}, \"planner\": {\"id\": \"$PLA\"},
  \"source\": {\"id\": \"$SRC\"}, \"group\": \"pyme\", \"state\": \"running\",
  \"autonomous\": 1, \"obfuscator\": \"plain-text\", \"jitter\": \"1/2\", \"auto_close\": true}" | jq -r .id)
echo "operacion $OP en marcha contra el grupo pyme"; echo

VISTAS=""
for i in $(seq 1 120); do
  for L in $(curl -s -H "$K" "$C/api/v2/operations/$OP/links" | jq -r '.[] | select(.status != -3) | .id'); do
    case "$VISTAS" in *"$L"*) continue ;; esac
    VISTAS="$VISTAS $L"
    R=$(curl -s -H "$K" "$C/api/v2/operations/$OP/links/$L/result")
    printf '  [%s] %s\n' "$(echo "$R" | jq -r .link.ability.technique_id)" \
                         "$(echo "$R" | jq -r .link.ability.name)"
    printf '      $ %s\n' "$(echo "$R" | jq -r .link.plaintext_command | head -c 88)"
    echo "$R" | jq -r '.result | @base64d | fromjson.stdout' | head -3 | sed 's/^/        /'
  done
  [ "$(curl -s -H "$K" "$C/api/v2/operations/$OP" | jq -r .state)" = "finished" ] && break
  sleep 2
done
echo; echo "cadena terminada: $(echo $VISTAS | wc -w) acciones ATT&CK ejecutadas en el servidor"
