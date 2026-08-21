#!/bin/bash
# Una copia que falla EN SILENCIO es peor que no tener copia: crees que estás cubierto.
# Esto no mira si el script "se ejecutó": mira si el espejo ESTÁ y qué EDAD tiene lo
# último que hay dentro. Son las dos formas reales de quedarte sin copia sin enterarte.
set -eu
ESPEJO="respaldo/facturas"
MAX_HORAS="${MAX_HORAS:-26}"     # 24 h de margen + 2 h de holgura

# 1 · ¿está el espejo? Un disco que se soltó no da ningún error: simplemente no está.
if ! zfs list -H "$ESPEJO" >/dev/null 2>&1; then
    echo "ALERTA: el espejo no está disponible. NO hay copia."
    exit 1
fi

# 2 · ¿y qué edad tiene lo último que recibió?
ULTIMA=$(zfs list -H -p -o creation -t snapshot -s creation -d 1 "$ESPEJO" | tail -1)
HORAS=$(( ( $(date +%s) - ULTIMA ) / 3600 ))

if [ "$HORAS" -gt "$MAX_HORAS" ]; then
    echo "ALERTA: la última instantánea del espejo tiene $HORAS horas (máximo $MAX_HORAS)"
    exit 1
fi
echo "OK: el espejo está y su última copia tiene $HORAS horas"
