#!/bin/bash
# El antes y el despues sobre la MISMA lista y la misma maquina.
# Izquierda: un resolutor normal. Derecha: AdGuard Home del laboratorio.
set -u
LISTA="${1:-dominios.txt}"
SIN="1.1.1.1"          # un resolutor cualquiera, sin filtrar
CON="10.10.10.10"      # AdGuard Home

mide() {               # mide <servidor> -> "resueltos bloqueados"
  local srv="$1" ok=0 ko=0 r
  while read -r d; do
    case "$d" in ''|'#'*) continue;; esac
    r=$(dig +short +time=2 +tries=1 @"$srv" "$d" A 2>/dev/null \
        | grep -m1 -E '^[0-9]+\.')
    [ -n "$r" ] && ok=$((ok+1)) || ko=$((ko+1))
  done < "$LISTA"
  echo "$ok $ko"
}

TOT=$(grep -cvE '^\s*(#|$)' "$LISTA")
printf '\n  %d dominios que contactan un movil y un televisor\n' "$TOT"
printf '  cuando NADIE los esta tocando\n\n'

read -r A_OK A_KO < <(mide "$SIN")
printf '  SIN FILTRO  (%s)    resueltos: %2d   bloqueados: %2d\n' "$SIN" "$A_OK" "$A_KO"

read -r B_OK B_KO < <(mide "$CON")
printf '  CON ADGUARD (%s)  resueltos: %2d   bloqueados: %2d\n' "$CON" "$B_OK" "$B_KO"

printf '\n  ==> %d de %d NI SALEN de casa = %d%% de publicidad y rastreo\n' \
       "$B_KO" "$TOT" $(( B_KO * 100 / TOT ))
printf '      cortado en el DNS, para TODOS los equipos, sin tocarlos\n\n'
