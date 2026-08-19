# tut53 — ¿Quién apagó esa VM? Proxmox te lo dice

Auditoría y cumplimiento en Proxmox: quién hizo qué, cuándo, y cómo demostrarlo
después aunque el nodo esté comprometido. Tres piezas: los registros que Proxmox
ya escribe, un colector central que los saca del nodo antes de que se puedan
borrar, y un informe periódico firmado criptográficamente.

## La cadena de auditoría en 3 piezas

| Pieza | Qué hace | Limitación que resuelve la siguiente |
|---|---|---|
| **Registros de Proxmox** | `/var/log/pve/tasks/index` (tareas) y `/var/log/pveproxy/access.log` (API) | Son locales, se rotan y quien administra el nodo puede borrarlos |
| **Colector central** (`crear-colector.sh`) | LXC con `systemd-journal-remote` que recibe el journal de todos los nodos en tiempo real | El colector guarda una copia fuera del nodo, pero nadie firma que no se haya tocado |
| **Informe firmado** (`informe-cambios.sh` + `verificar-informe.sh`) | Filtra los cambios, cuenta llamadas de escritura por usuario, calcula SHA-256 de las fuentes y firma con Ed25519 | Cualquiera con la clave pública prueba que el informe no se ha manipulado |

### 1. Lo que Proxmox ya escribe

**`/var/log/pve/tasks/index`** — un UPID por línea, separado por `:`:

```
UPID:<nodo>:<pid hex>:<pstart hex>:<hora inicio hex>:<tipo>:<objeto>:<usuario>:
```

seguido de `<hora fin hex> <resultado>`. Ejemplo real del lab:

```
UPID:proxmox:002E1525:15891790:6A858137:qmstop:4805:operador@pve!portatil: 6A858137 OK
```

**`/var/log/pveproxy/access.log`** — registro de la API, formato tipo servidor web
(IP de origen, usuario, método, ruta, código):

```
::ffff:192.168.1.78 - operador@pve!portatil [19/08/2026:12:20:59 +0200] "POST /api2/json/nodes/proxmox/qemu/4805/status/stop HTTP/1.1" 200 85
```

Los dos son **locales**: se rotan con el tiempo y quien tiene acceso root al nodo
puede editarlos o borrarlos. No sirven solos como prueba.

### 2. Centralización — colector con `systemd-journal-remote`

`crear-colector.sh` monta un LXC Debian 13 (`auditoria`) que escucha en el puerto
**19532**. Cada nodo del clúster sube su journal en tiempo real con
`systemd-journal-upload` (`/etc/systemd/journal-upload.conf`, línea
`URL=http://<ip-colector>:19532`).

**Trampa importante**: en Debian, `systemd-journal-remote` arranca por defecto
con `--listen-https=-3`. Sin certificados configurados, el servicio **muere** con:

```
Failed to read key from file '/etc/ssl/private/journal-remote.pem': Permission denied
```

La vía limpia **dentro de la red de gestión** es un drop-in en
`/etc/systemd/system/systemd-journal-remote.service.d/http.conf` que fuerza
`--listen-http=-3` (HTTP, sin certificado). Si el colector se expone fuera de la
red de gestión, los certificados pasan a ser obligatorios — no hay atajo.

`/etc/systemd/journal-remote.conf` fija `SplitMode=host` (un fichero de journal
por nodo), `MaxUse=2G` y `MaxFileSize=128M`: retención acotada, el colector nunca
se llena.

Aviso práctico: la **primera vez** que arranca, `systemd-journal-upload` sube
TODO el histórico del journal del nodo (puede tardar minutos y pesar decenas de
MB) antes de pasar a subir en tiempo real.

Lectura en el colector:

```bash
journalctl -D /var/log/journal/remote -t pvedaemon -n 20
```

### 3. Informe firmado

`informe-cambios.sh` recorre `/var/log/pve/tasks/index`, se queda solo con las
tareas que **cambian** algo (arrancar/parar/destruir VM o CT, snapshots,
migraciones, ACL, usuarios — las consultas no cuentan), cuenta las llamadas de
escritura (POST/PUT/DELETE) a la API por usuario, calcula el SHA-256 de las dos
fuentes (cadena de custodia) y firma el informe completo con Ed25519
(`openssl pkeyutl -sign -rawin`).

`verificar-informe.sh` comprueba la firma contra la clave pública:

- Informe intacto → `Signature Verified Successfully`
- Una sola línea cambiada → `Signature Verification Failure`

Generación de las claves (una sola vez):

```bash
openssl genpkey -algorithm ED25519 -out auditoria.key
chmod 600 auditoria.key
openssl pkey -in auditoria.key -pubout -out auditoria.pub
```

La clave **privada** se guarda **fuera** del nodo (si el nodo se ve comprometido,
no debe poder falsificar informes nuevos). La clave **pública** se reparte a
quien tenga que verificar.

Automatización con `informe-cambios.cron` (instalado como
`/etc/cron.d/informe-cambios`): informe diario firmado a las 06:00.

## Datos reales del laboratorio

Medidos sobre el nodo `proxmox` del lab, informe de 1 día:

| Dato | Valor |
|---|---|
| Cambios detectados | 24 cambios en 1 día |
| Llamadas de escritura de `operador@pve!portatil` | 4 |
| Tamaño del informe | 2633 bytes |
| Tamaño de la firma Ed25519 | 64 bytes |
| Usuario del ejemplo | `operador@pve`, token `operador@pve!portatil`, ACL `PVEVMAdmin` sobre `/vms/4805` |

## Ficheros

| Fichero | Para qué |
|---|---|
| `comandos.md` | todos los comandos del vídeo, en orden |
| `crear-colector.sh` | monta el LXC colector con `systemd-journal-remote` |
| `informe-cambios.sh` | genera el informe de cambios y lo firma con Ed25519 |
| `verificar-informe.sh` | comprueba que un informe no se ha tocado desde que se firmó |
| `informe-cambios.cron` | cron diario (06:00) para `/etc/cron.d/informe-cambios` |

## Enlaces

- https://github.com/logicalpeyote777/morinicomputers
- https://morinicomputers.com/morini/proxmox/
