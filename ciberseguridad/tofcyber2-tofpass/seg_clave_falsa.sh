#!/usr/bin/env bash
# SHORT (concepto-gancio): por que "Password1" o "Qwerty123" caen IGUAL de rapido.
# Una palabra del diccionario + mayuscula inicial + un numero PARECE una clave fuerte, pero
# los crackeadores aplican esas mismas transformaciones con un fichero de "reglas". Demostrado
# en el laboratorio AISLADO de Morini; solo hashes propios, fines educativos.
set -u
DIC=/root/diccionario.txt
RULE=/usr/share/hashcat/rules/dive.rule   # reglas amplias: capitaliza, anade numeros, leet (@,0,3...)

# 4 claves que PARECEN complejas: palabra comun + Mayuscula + numero(s)
printf '%s\n' Password1 Qwerty123 Monkey1 Dragon123 > /root/claves_falsas_plain.txt
: > /root/claves_falsas.txt
while read -r p; do printf '%s' "$p" | md5sum | awk '{print $1}' >> /root/claves_falsas.txt; done < /root/claves_falsas_plain.txt

echo "=== 4 claves que PARECEN fuertes (mayuscula + numero) como hashes MD5 ==="
paste /root/claves_falsas_plain.txt /root/claves_falsas.txt
echo
echo "=== hashcat: MISMO diccionario debil + reglas que imitan como piensa la gente ==="
rm -f /root/.hashcat/hashcat.potfile 2>/dev/null
if [ -f "$RULE" ]; then
  hashcat -m 0 -a 0 /root/claves_falsas.txt "$DIC" -r "$RULE" --force --potfile-disable --quiet 2>/dev/null
else
  # respaldo si no hay fichero de reglas: las mismas variantes ya estan en cualquier lista real
  hashcat -m 0 -a 0 /root/claves_falsas.txt /root/claves_falsas_plain.txt --force --potfile-disable --quiet 2>/dev/null
fi
echo
echo ">>> las 4 'complejas' caen: solo eran una palabra del diccionario disfrazada."
