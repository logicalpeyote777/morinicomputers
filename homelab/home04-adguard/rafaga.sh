#!/bin/bash
# Una rafaga de 200 consultas desde UN SOLO equipo.
# Es lo que ve AdGuard cuando el router reenvia el DNS de toda la casa:
# para el, la casa entera es una unica direccion IP.
set -u
N=200
R=$(seq 1 $N | xargs -P 40 -I{} sh -c \
    'dig +short +time=2 +tries=1 -b 10.10.10.21 @10.10.10.10 \
       r{}-$RANDOM.debian.org A >/dev/null 2>&1 \
     && echo RESPONDIDA || echo SIN-RESPUESTA')
OK=$(printf '%s\n' "$R" | grep -c RESPONDIDA)
KO=$(printf '%s\n' "$R" | grep -c SIN-RESPUESTA)
printf '\n  %d consultas en rafaga desde 10.10.10.21\n' "$N"
printf '  respondidas   : %3d\n' "$OK"
printf '  SIN RESPUESTA : %3d   (%d%%)\n\n' "$KO" $(( KO * 100 / N ))
