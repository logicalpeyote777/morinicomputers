#!/bin/bash
# privesc.sh - chequeo rapido de vias de escalada de privilegios en Linux.
# Morini Computers - hacking etico - laboratorio AISLADO y propio. Solo fines educativos.
# Se ejecuta como el usuario sin privilegios al que ya tienes acceso (la "shell inicial").
# Automatiza la enumeracion manual del video: quien soy, que puedo hacer y por donde escalar.

echo "===================================================="
echo " privesc.sh - enumeracion de escalada (lab Morini)"
echo "===================================================="

echo; echo "[1] Usuario actual y grupos:"
id

echo; echo "[2] Permisos sudo (sudo -l):"
sudo -n -l 2>/dev/null || echo "    sin sudo o requiere contrasena"

echo; echo "[3] Binarios SUID (corren como su propietario, normalmente root):"
find / -perm -4000 -type f 2>/dev/null

echo; echo "[4] Capabilities peligrosas (cap_setuid, cap_dac, etc.):"
# getcap suele vivir en /sbin, que no esta en el PATH de un usuario normal -> ruta completa
/sbin/getcap -r / 2>/dev/null || getcap -r / 2>/dev/null || echo "    getcap no disponible"

echo; echo "[5] Version del kernel (posibles exploits conocidos):"
uname -r

echo; echo "[6] Ficheros sensibles y sus permisos:"
ls -l /etc/passwd /etc/shadow 2>/dev/null

echo; echo "[*] Revisa: SUID raros, sudo NOPASSWD y capabilities -> son tus billetes a root."
