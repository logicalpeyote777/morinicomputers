# tut28 — Acceso remoto a Proxmox: VPN WireGuard en un LXC

Scripts del tutorial «Accede a tu Proxmox desde cualquier lugar de forma segura:
VPN WireGuard en un contenedor LXC» de Morini Computers (YouTube).

## comandos-vpn.sh

Todos los comandos del vídeo, en orden y comentados: contenedor LXC, instalación
(`--no-install-recommends wireguard-tools`), claves, `wg0.conf` del servidor con NAT,
reenvío de paquetes, servicio, cliente + QR. Para ejecutar **uno a uno**, no de golpe.

## anadir-cliente.sh

Alta de un dispositivo nuevo en la VPN con un solo comando (en el contenedor):

```bash
bash anadir-cliente.sh movil
```

Calcula la siguiente IP libre, genera las claves, añade el `[Peer]` al servidor,
escribe el `.conf` del cliente, recarga el túnel sin cortar a nadie e imprime el QR.
Edita `ENDPOINT` con tu IP pública o dominio DDNS.

## El error típico

`wg-quick up` dentro del LXC falla con «Unknown device type»: el módulo del kernel
se carga en el **host** Proxmox, no en el contenedor →
`modprobe wireguard && echo wireguard > /etc/modules-load.d/wireguard.conf`
