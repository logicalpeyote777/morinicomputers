#!/bin/bash
# auditar.sh - revisa las protecciones de compilacion de un binario PROPIO
# y dice exactamente que bandera de gcc te falta.
# Uso: ./auditar.sh <binario>
# Codigo completo: github.com/logicalpeyote777/morinicomputers
BIN=${1:?uso: ./auditar.sh <binario>}
S=$(checksec --file="$BIN" 2>&1)
echo "== $BIN =="
chk(){ if echo "$S" | grep -q "$1"; then echo "  [OK]    $2"; else echo "  [FALTA] $2 ->  $3"; fi; }
chk "Canary found" "canario de pila      " "-fstack-protector-strong"
chk "NX enabled"   "pila no ejecutable   " "-z noexecstack"
chk "PIE enabled"  "PIE (ASLR del codigo)" "-pie -fPIE"
chk "Full RELRO"   "RELRO completo       " "-Wl,-z,relro,-z,now"
# FORTIFY deja huella: las funciones _chk (memcpy_chk, printf_chk...) en el binario
if nm -D "$BIN" 2>/dev/null | grep -q "_chk"; then
  echo "  [OK]    FORTIFY_SOURCE       "
else
  echo "  [FALTA] FORTIFY_SOURCE        ->  -O2 -D_FORTIFY_SOURCE=2"
fi
