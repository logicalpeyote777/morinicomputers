#!/usr/bin/env bash
# sqli_login.sh -- inicia sesion en MI DVWA del laboratorio aislado y deja lista la cookie
# de sesion para atacar la pagina vulnerable de inyeccion SQL.
#
#   source sqli_login.sh [nivel]     # nivel = low (def) | impossible
#
# Al cargarlo con "source" exporta dos variables en tu shell:
#   COOKIE -> "PHPSESSID=...; security=<nivel>"  (lista para curl y sqlmap)
#   U      -> URL de la pagina vulnerable de SQLi
# SOLO contra sistemas propios y autorizados. Laboratorio aislado, sin salida a internet.
# Morini Computers -- Ciberseguridad. Encuadre educativo y de defensa.
URL="http://10.13.37.30"            # MI DVWA en el laboratorio aislado (sin salida a internet)
LEVEL="${1:-low}"                   # nivel de seguridad de DVWA (low = vulnerable)
JAR="$(mktemp)"                     # galleta de sesion (cookie jar)

# Extrae el token anti-CSRF (campo oculto user_token) del HTML de una pagina.
tok() { grep -oE "user_token' value='[0-9a-f]+'" | grep -oE '[0-9a-f]{16,}' | head -1; }

# 1) pido login.php y robo el token anti-CSRF
T1=$(curl -s -c "$JAR" "$URL/login.php" | tok)
# 2) inicio sesion como admin enviando ese token con las credenciales
curl -s -b "$JAR" -c "$JAR" -L \
     --data-urlencode "username=admin" --data-urlencode "password=password" \
     --data-urlencode "user_token=$T1" --data "Login=Login" "$URL/login.php" >/dev/null
# 3) fijo el nivel de seguridad de DVWA (low = la inyeccion es posible)
T2=$(curl -s -b "$JAR" -c "$JAR" "$URL/security.php" | tok)
curl -s -b "$JAR" -c "$JAR" \
     --data "security=$LEVEL" --data "seclev_submit=Submit" \
     --data-urlencode "user_token=$T2" "$URL/security.php" >/dev/null
# 4) compongo la cookie (PHPSESSID + security) y la exporto, junto con la URL vulnerable
SID=$(awk '/PHPSESSID/{print $7}' "$JAR")
rm -f "$JAR"
export COOKIE="PHPSESSID=$SID; security=$LEVEL"
export U="$URL/vulnerabilities/sqli/"
echo "COOKIE = $COOKIE"
echo "U      = $U"
