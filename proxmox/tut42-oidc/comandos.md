# tut42 — Comandos del vídeo, en orden

> Host: Proxmox VE 9.2.3 en `192.168.1.29`. Keycloak: LXC 220 en `192.168.1.220`.
> Cambia las direcciones por las tuyas.

## 0) El punto de partida

```bash
grep ^user: /etc/pve/user.cfg
pveum realm list
```

## 1) El contenedor del proveedor de identidad

```bash
pct create 220 local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst \
  --hostname sso --cores 2 --memory 2048 --swap 512 --rootfs vmstore:8 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.220/24,gw=192.168.1.1 \
  --nameserver 8.8.8.8 --unprivileged 1 --features nesting=1

pct start 220
pct exec 220 -- ip -4 -br a
```

> `--features nesting=1` no es opcional: systemd 257 dentro de un contenedor sin
> anidamiento no arranca bien.

## 2) Keycloak

```bash
pct push 220 instalar-keycloak.sh /root/instalar-keycloak.sh -perms 755
pct exec 220 -- bash /root/instalar-keycloak.sh

pct exec 220 -- systemctl is-active keycloak
curl -s http://192.168.1.220:8080/realms/master/.well-known/openid-configuration \
  | jq -r '.issuer, .authorization_endpoint, .token_endpoint'
```

## 3) Realm, cliente OIDC, grupos y mapeador

```bash
pct push 220 configurar-realm.sh /root/configurar-realm.sh -perms 755
pct exec 220 -- bash /root/configurar-realm.sh     # imprime CLIENT_SECRET
```

## 4) El realm OpenID Connect en Proxmox

```bash
pveum realm add keycloak --type openid \
  --issuer-url http://192.168.1.220:8080/realms/morini \
  --client-id proxmox --client-key <CLIENT_SECRET> \
  --username-claim username --autocreate 1 \
  --groups-claim groups --groups-autocreate 1 --groups-overwrite 1 \
  --comment 'SSO corporativo Morini'

pveum realm list
```

| Bandera | Para qué |
|---|---|
| `--issuer-url` | Exactamente el `issuer` del documento de descubrimiento, ni una barra de más. |
| `--username-claim username` | El usuario de Proxmox sale de `preferred_username`, no del `sub`. |
| `--autocreate 1` | La cuenta se crea sola en el primer inicio de sesión. |
| `--groups-claim groups` | De qué claim leer los grupos. |
| `--groups-autocreate 1` | Proxmox crea el grupo si no existe. |
| `--groups-overwrite 1` | En cada login recalcula los grupos desde el directorio. |

## 5) Cuando entra pero no puede nada — diagnóstico

```bash
grep keycloak /etc/pve/user.cfg
pveum group list
journalctl -u pvedaemon --since '-10min' | grep -i openid | tail -5
# -> openid group '/pve-admins' contains invalid characters
```

Arreglo (ver README):

```bash
kc(){ pct exec 220 -- /opt/keycloak/bin/kcadm.sh "$@" </dev/null; }
pct exec 220 -- /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 --realm master --user admin --password '<TU_CLAVE>'

CID=$(kc get clients -r morini -q clientId=proxmox --fields id --format csv --noquotes)
kc get clients/$CID/protocol-mappers/models -r morini | jq -r '.[] | {name, config}'
MID=$(kc get clients/$CID/protocol-mappers/models -r morini \
      --fields id,name --format csv --noquotes | grep grupos | cut -d, -f1)
kc update clients/$CID/protocol-mappers/models/$MID -r morini -s 'config."full.path"=false'
kc get clients/$CID/protocol-mappers/models/$MID -r morini | jq -r '.config."full.path"'
```

## 6) Grupos → roles

```bash
pveum group list        # aparecen solos tras el primer login: <grupo>-<realm>
pveum acl modify / -group pve-admins-keycloak     -role Administrator
pveum acl modify / -group pve-operadores-keycloak -role PVEVMAdmin
pveum acl modify / -group pve-auditores-keycloak  -role PVEAuditor
pveum acl list | grep keycloak
```

Comprobación:

```bash
pveum user permissions carlos@keycloak | head -14
pveum user permissions carlos@keycloak | grep -c 'Sys\.'   # 0
pveum user permissions ana@keycloak    | grep -c 'Sys\.'   # 70
```

## 7) Alta de un empleado

```bash
pct push 220 alta-usuario.sh /root/alta-usuario.sh -perms 755
pct exec 220 -- /root/alta-usuario.sh marta 'Marta Gil' pve-operadores
grep keycloak /etc/pve/user.cfg    # marta AÚN no está en Proxmox: se creará al entrar
```

## 8) Baja de un empleado

```bash
kc update users/$(kc get users -r morini -q username=carlos \
   --fields id --format csv --noquotes) -r morini -s enabled=false
```

La ficha sigue en `/etc/pve/user.cfg`, pero ya no es una credencial: sin el directorio
detrás, no puede autenticarse.
