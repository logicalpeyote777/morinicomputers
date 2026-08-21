#!/bin/bash
# comparar.sh - pone las dos mediciones lado a lado. Mismo servidor, misma carga,
# misma prueba: lo unico que ha cambiado es la configuracion de la VM.
val() { grep -oP "$2:\s*\K[0-9]+" "/root/rt/$1.txt" | sort -n | tail -1; }
fila() { printf "  %-26s %9s %9s %11s\n" "$2" "$(val $1 Min)" "$(val $1 Avg)" "$(val $1 Max)"; }

printf "  %-26s %9s %9s %11s\n" "" "Min(us)" "Avg(us)" "Max(us)"
printf "  %-26s %9s %9s %11s\n" "--------------------------" "-------" "-------" "---------"
fila antes   "ANTES  por defecto"
fila despues "DESPUES pin+HP+aislado"
echo
A=$(val antes Max); D=$(val despues Max)
awk -v a="$A" -v d="$D" 'BEGIN{
  printf "  peor caso: %d us -> %d us   =  %.1f veces mejor\n", a, d, a/d;
  printf "  en cristiano: %.1f ms de parada -> %.2f ms\n", a/1000, d/1000;
}'
