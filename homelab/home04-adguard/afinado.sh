#!/bin/bash
# Las dos cosas que separan "resuelve" de "resuelve bien".
set -u
A=10.10.10.10

echo "== la cache: vacia, y la misma consulta dos veces ======================="
curl -s -u homelab:clave-falsa-de-laboratorio -X POST http://10.10.10.10:8090/control/cache_clear >/dev/null
printf '   1a vez (sale a internet, cifrada) : '; dig +noall +stats @$A videolan.org A | grep -o '[0-9]* msec'
printf '   2a vez (ya la tienes en casa)     : '; dig +noall +stats @$A videolan.org A | grep -o '[0-9]* msec'

echo
echo "== la regla por equipo: la tablet no, el televisor si ==================="
printf '   tablet-ninos (10.10.10.23) -> tiktok.com : '
dig +short -b 10.10.10.23 @$A tiktok.com A | grep -qE '^[0-9]' && echo "resuelve" || echo "BLOQUEADO"
printf '   tv-salon     (10.10.10.21) -> tiktok.com : '
dig +short -b 10.10.10.21 @$A tiktok.com A | grep -qE '^[0-9]' && echo "resuelve" || echo "BLOQUEADO"
