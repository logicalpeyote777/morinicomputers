#!/bin/bash
# salud.sh — lo que "smartctl -H" NO te dice, de todos los discos, de un vistazo.
# Los 5 atributos que Backblaze correlaciona con fallo real, el margen de vida
# que le queda al disco y la temperatura. Nada mas: el resto es ruido.
CRIT="5 187 188 197 198"

for D in $(lsblk -dn -e 7,230 -o NAME); do
  DEV=/dev/$D
  A=$(sudo smartctl -A -d sat "$DEV")            # -d sat: SIN esto no hay tabla
  echo "-- $DEV  $(lsblk -dn -o MODEL "$DEV")"

  AVISO=""
  for ID in $CRIT; do
    read -r _ NOM _ VAL _ THR _ _ _ RAW <<<"$(awk -v i="$ID" '$1==i' <<<"$A")"
    [ -z "$NOM" ] && { printf '   %-3s  -- este disco no tiene este atributo\n' "$ID"; continue; }
    EST=ok
    [ "${RAW%% *}" != 0 ] && [ "$ID" != 188 ] && { EST="OJO: ya no es cero"; AVISO=1; }
    [ "$((10#$VAL))" -le "$((10#$THR))" ] && { EST="FALLANDO AHORA"; AVISO=1; }
    printf '   %-3s %-24s val %s / umbral %s   raw %-12s %s\n' \
           "$ID" "$NOM" "$VAL" "$THR" "${RAW%% *}" "$EST"
  done

  # cuanto del recorrido util (de 100 al umbral) se ha comido ya cada pre-fail
  GAST=$(awk '/Pre-fail/{v=$4+0;t=$6+0; if(t>0 && v<=100){g=(100-v)*100/(100-t); if(g>mx){mx=g; n=$2"  val "v" / umbral "t}}} END{if(n) printf "%s  ->  %d%% consumido", n, mx+0.5; else print "-"}' <<<"$A")
  TEMP=$(awk '$2=="Temperature_Celsius"{print $10; exit}' <<<"$A")
  echo "   pre-fail mas consumido: $GAST"
  echo "   temperatura: ${TEMP:-?} C"
  [ -n "$AVISO" ] && echo "   >> NO te fies del PASSED: hay algo que mirar" \
                  || echo "   >> sin senales de fallo en los 5 criticos"
  echo
done
