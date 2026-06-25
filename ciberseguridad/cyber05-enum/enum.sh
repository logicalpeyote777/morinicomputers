#!/usr/bin/env bash
# enum.sh -- enumeracion A FONDO de UNA maquina de TU laboratorio: servicios, web y SMB.
# Uso:  ./enum.sh <host_servicios> [host_web]
#   host_servicios -> nmap NSE (servicios+version) y SMB (recursos y usuarios)  [def 10.13.37.20]
#   host_web       -> gobuster de directorios y ficheros web                    [def 10.13.37.30]
# SOLO para sistemas propios y autorizados. Laboratorio aislado, sin salida a internet.
# Morini Computers -- Ciberseguridad. Encuadre educativo y de defensa.
set -u
HOST="${1:-10.13.37.20}"
WEB="${2:-10.13.37.30}"
WL="/usr/share/dirb/wordlists/common.txt"
OUT="enum_${HOST}.txt"
: > "$OUT"
echo "[*] servicios/SMB: $HOST   |   web: $WEB   ->   informe: $OUT"

echo "[1] Servicios, versiones y scripts por defecto (Nmap NSE -sV -sC)"
nmap -n -sV -sC --open -p 21,22,25,80,139,445 "$HOST" -oN "$OUT" \
  | grep -E '^[0-9]+/tcp|Samba|OpenSSH|vsftpd|Postfix'

echo "[2] Directorios y ficheros web ocultos (gobuster)"
gobuster dir -u "http://$WEB" -w "$WL" -t 40 -q 2>/dev/null | tee -a "$OUT"

echo "[3] SMB: recursos compartidos por sesion nula y usuarios"
smbclient -L "//$HOST" -N 2>/dev/null | grep -E 'Disk|IPC' | tee -a "$OUT"
enum4linux -U "$HOST" 2>/dev/null | grep -E 'user:\[' | tee -a "$OUT"

echo "[4] Listo. Mapa del objetivo guardado en: $OUT"
ls -l "$OUT"
