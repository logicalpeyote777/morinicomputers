#!/bin/bash
# ?Filtra de verdad, y filtra SOLO lo que queremos?
set -u
A=10.10.10.10

echo "== 1. un dominio de publicidad =========================================="
dig +noall +comments @$A doubleclick.net A | grep 'status:'

echo
echo "== 2. un dominio legitimo ==============================================="
dig +noall +comments +answer @$A debian.org A | grep -E 'status:|^debian'

echo
echo "== 3. la EXCEPCION: lo que tu decides dejar pasar ========================"
echo "   regla:  @@||ads.linkedin.com^   (esta en las listas, pero marketing lo necesita)"
dig +noall +comments +answer @$A ads.linkedin.com A | grep -E 'status:|^ads'
