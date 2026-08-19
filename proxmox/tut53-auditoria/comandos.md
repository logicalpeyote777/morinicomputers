# Comandos del vídeo, en orden

## 0. Preparar un usuario de prueba (para generar actividad auditable)

```bash
pveum user token add operador@pve portatil --privsep 0
```
Crea el token API `operador@pve!portatil`, sin privilegios separados: hereda los
permisos del usuario.

```bash
pveum acl modify /vms/4805 --users operador@pve --roles PVEVMAdmin
```
Da al usuario `operador@pve` el rol `PVEVMAdmin` (arrancar/parar/gestionar VM)
únicamente sobre la VM 4805 — permisos mínimos, no admin de clúster.

## 1. Generar actividad vía API (lo que vamos a auditar después)

```bash
curl -sk -H "Authorization: PVEAPIToken=$(cat token)" \
     -X POST https://<nodo>:8006/api2/json/nodes/<nodo>/qemu/<vmid>/status/stop
```
Apaga la VM usando el token, no una sesión interactiva — así queda registrada
como llamada API con IP de origen, igual que la usaría una automatización.

## 2. Leer los dos registros que Proxmox ya escribe

```bash
tail -20 /var/log/pve/tasks/index
```
Registro de tareas: un UPID por línea con nodo, tipo de tarea, objeto y usuario.

```bash
tail -20 /var/log/pveproxy/access.log
```
Registro de acceso de la API: IP, usuario, método HTTP, ruta, código de
respuesta.

## 3. Montar el colector central

```bash
./crear-colector.sh
```
Monta el LXC `auditoria` (CT 231) con `systemd-journal-remote` escuchando en el
puerto 19532, en HTTP dentro de la red de gestión (drop-in
`--listen-http=-3`, sin certificados).

## 4. Subir el journal de cada nodo al colector

```bash
apt-get install -y systemd-journal-upload
```
Instala el emisor en el nodo Proxmox.

```bash
sed -i 's#^#URL=http://192.168.1.231:19532\n#' /etc/systemd/journal-upload.conf
```
Apunta el nodo al colector (`/etc/systemd/journal-upload.conf`,
`URL=http://<ip-colector>:19532`).

```bash
systemctl enable --now systemd-journal-upload
```
Arranca la subida. La primera vez sube todo el histórico del journal (minutos,
decenas de MB) antes de pasar a tiempo real.

## 5. Leer en el colector lo que ha llegado

```bash
journalctl -D /var/log/journal/remote -t pvedaemon -n 20
```
Journal del nodo, ya centralizado y fuera de su alcance si el nodo se ve
comprometido.

## 6. Generar las claves de firma (una sola vez)

```bash
openssl genpkey -algorithm ED25519 -out auditoria.key
chmod 600 auditoria.key
openssl pkey -in auditoria.key -pubout -out auditoria.pub
```
Clave privada Ed25519 (permisos 600, se saca del nodo) y su pública derivada
(se reparte a quien verifique).

## 7. Generar el informe firmado

```bash
./informe-cambios.sh 1
```
Filtra las tareas de tipo cambio de las últimas 24h, cuenta llamadas de
escritura por usuario, calcula SHA-256 de las fuentes y firma el resultado con
`openssl pkeyutl -sign -rawin`. En el lab: 24 cambios, informe de 2633 bytes,
firma de 64 bytes.

## 8. Verificar que nadie lo ha tocado

```bash
./verificar-informe.sh /root/audit/informes/cambios-2026-08-19.txt
```
`Signature Verified Successfully` si el fichero está intacto.

## 9. Manipular el informe y volver a verificar (demo de la trampa)

```bash
sed -i '3s/.*/línea cambiada/' /root/audit/informes/cambios-2026-08-19.txt
./verificar-informe.sh /root/audit/informes/cambios-2026-08-19.txt
```
Con una sola línea distinta, la verificación da `Signature Verification
Failure`: la firma detecta cualquier modificación, por mínima que sea.

## 10. Automatizar el informe diario

```bash
cp informe-cambios.cron /etc/cron.d/informe-cambios
```
Genera y firma el informe todos los días a las 06:00, sin intervención manual.
