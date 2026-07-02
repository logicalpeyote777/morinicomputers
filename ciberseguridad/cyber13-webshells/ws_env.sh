#!/usr/bin/env bash
# ws_env.sh -- inicia sesion en MI DVWA del laboratorio aislado y deja lista la sesion
# para las tres puertas de este video: Command Injection, LFI/RFI y subida de archivos.
#
#   source ws_env.sh [nivel]     # nivel = low (def) | impossible
#
# Al cargarlo con "source" exporta en tu shell:
#   COOKIE -> "PHPSESSID=...; security=<nivel>"   (lista para curl)
#   EXEC   -> pagina vulnerable de Command Injection (ping)
#   FI     -> pagina vulnerable de File Inclusion (LFI/RFI)
#   UP     -> pagina de subida de archivos
#   SHELL  -> URL desde la RAIZ donde acaba la webshell subida
#   KALI   -> mi servidor de payloads para el RFI (corre en la propia Kali)
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
# 3) fijo el nivel de seguridad de DVWA
T2=$(curl -s -b "$JAR" -c "$JAR" "$URL/security.php" | tok)
curl -s -b "$JAR" -c "$JAR" \
     --data "security=$LEVEL" --data "seclev_submit=Submit" \
     --data-urlencode "user_token=$T2" "$URL/security.php" >/dev/null
# 4) compongo la cookie de sesion y exporto las URLs de las tres puertas del video
SID=$(awk '/PHPSESSID/{print $7}' "$JAR"); rm -f "$JAR"
export COOKIE="PHPSESSID=$SID; security=$LEVEL"
export EXEC="$URL/vulnerabilities/exec/"
export FI="$URL/vulnerabilities/fi/"
export UP="$URL/vulnerabilities/upload/"
export SHELL="$URL/hackable/uploads/shell.php"
export KALI="http://10.13.37.10:8000"
echo "COOKIE = $COOKIE"
echo "EXEC   = $EXEC"
echo "FI     = $FI"
echo "UP     = $UP"
