#!/bin/bash
# bench.sh <etiqueta> — CLIENTES sincronizando A LA VEZ por WebDAV, como la
# aplicacion de escritorio. Mide tiempo, subidas correctas, fallos y fich/s.
ETIQ="${1:-prueba}"
URL="http://10.10.10.10:8080/remote.php/dav/files/homelab"
AUTH="homelab:clave-falsa-de-laboratorio"
CLIENTES=8
FICHEROS=3
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
head -c 262144 /dev/urandom > "$TMP/f.bin"        # 256 KB por fichero

curl -s -o /dev/null -u "$AUTH" -X MKCOL "$URL/bench-$ETIQ"
cliente() {                                        # un cliente = un proceso
  for i in $(seq 1 $FICHEROS); do
    curl -s -o /dev/null -w '%{http_code}\n' -u "$AUTH" \
         -T "$TMP/f.bin" "$URL/bench-$ETIQ/c$1-f$i.bin"
  done >> "$TMP/codigos"
}
echo "=== $ETIQ : $CLIENTES clientes x $FICHEROS ficheros = $((CLIENTES*FICHEROS)) subidas ==="
INI=$(date +%s%N)
for c in $(seq 1 $CLIENTES); do cliente "$c" & done
wait
T=$(( ($(date +%s%N) - INI) / 1000000 ))           # milisegundos
OK=$(grep -c '^2' "$TMP/codigos"); KO=$(grep -vc '^2' "$TMP/codigos")

printf "  tiempo total ...... %d,%03d s\n" $((T/1000)) $((T%1000))
printf "  subidas correctas . %s de %s\n" "$OK" "$((CLIENTES*FICHEROS))"
printf "  fallos ............ %s   %s\n" "$KO" \
       "$(sort "$TMP/codigos" | uniq -c | grep -v ' 2[0-9][0-9]' | tr -s '\n ' ' ')"
awk -v ok="$OK" -v t="$T" 'BEGIN{printf "  ficheros / segundo  %.1f\n", ok/(t/1000)}'

echo "$T" > ~/.bench-$ETIQ                          # para poder comparar despues
for OTRA in ~/.bench-*; do
  [ "$OTRA" = "$HOME/.bench-$ETIQ" ] && continue
  awk -v a="$(cat "$OTRA")" -v b="$T" -v n="$(basename $OTRA|sed s/.bench-//)" \
   'BEGIN{printf "  => %.1f VECES mas rapido que con %s (%.1f s)\n",a/b,n,a/1000}'
done
