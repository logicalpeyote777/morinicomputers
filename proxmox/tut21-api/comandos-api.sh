#!/bin/bash
# tut21 — La API de Proxmox: pvesh, tokens de API y curl.
# Comandos del vídeo, en orden. Ajusta IPs, VMIDs y nombres a tu entorno.
# NO es un script para lanzar a ciegas: son los pasos del tutorial, uno a uno.

### ─── Fase A: en el nodo Proxmox (pve-a) ───────────────────────────────────

# pvesh: la API entera desde la shell. La API es un ÁRBOL.
pvesh get /version
pvesh ls /

# Pasear por el árbol: dentro de un nodo (qemu, lxc, red, discos...) y su estado.
pvesh ls /nodes/pve-a
pvesh get /nodes/pve-a/status

# El inventario COMPLETO del clúster (todas las VMs de todos los nodos).
pvesh get /cluster/resources --type vm

# De leer (get) a tocar (create): arrancar una VM y comprobarla.
pvesh create /nodes/pve-a/qemu/240/status/start
pvesh get /nodes/pve-a/qemu/240/status/current

# Para automatizar, JAMÁS root: usuario propio para el «robot».
pveum user add automatiza@pve
pveum user list

# Su token de API (privsep=1: lista de permisos PROPIA, separada del usuario).
# ¡El secreto se enseña UNA sola vez! Guárdalo en el momento (tee).
pveum user token add automatiza@pve cli --privsep 1 | tee /root/token-cli.txt

# REGLA DE ORO con privsep: usuario Y token necesitan CADA UNO su permiso.
# (Si no se lo das al token: listas vacías y 403 «permission check failed».)
pveum acl modify /vms --users automatiza@pve --roles PVEVMAdmin
pveum acl modify /vms --tokens 'automatiza@pve!cli' --roles PVEVMAdmin

### ─── Fase B: desde OTRA máquina de la red (curl + jq) ─────────────────────

APIURL="https://192.168.1.71:8006/api2/json"       # tu Proxmox
H="Authorization: PVEAPIToken=automatiza@pve!cli=SECRETO-DEL-TOKEN"

# La versión, por HTTPS y sin sesión ni contraseña.
curl -sk -H "$H" $APIURL/version | jq .

# El inventario desde fuera (esto en un cron = inventario automático).
curl -sk -H "$H" "$APIURL/cluster/resources?type=vm" | jq '.data[] | {vmid, name, status, node}'

# Acciones = POST: apagar una VM y comprobar su estado.
curl -sk -X POST -H "$H" $APIURL/nodes/pve-a/qemu/240/status/stop | jq .
curl -sk -H "$H" $APIURL/nodes/pve-a/qemu/240/status/current | jq '.data.status'

# El gran final: CREAR una VM con un curl.
curl -sk -X POST -H "$H" -d vmid=260 -d name=creada-por-api -d memory=1024 -d cores=1 \
  $APIURL/nodes/pve-a/qemu | jq .
curl -sk -H "$H" "$APIURL/cluster/resources?type=vm" | jq '.data[] | {vmid, name, node}'
