# tut42 — SSO empresarial en Proxmox con OpenID Connect (Keycloak)

Tus empleados entran en Proxmox con el usuario y la contraseña de la empresa. La cuenta
se crea SOLA la primera vez que entran, sus grupos del directorio se convierten en roles
de Proxmox, el alta es un comando y la baja se cierra en un único sitio.

Vídeo: canal Morini Computers · https://www.youtube.com/@morinicomputers

## Ficheros
- `comandos.md` — todos los comandos del vídeo, en orden.
- `instalar-keycloak.sh` — Keycloak 26 sobre Debian 13 en un LXC (Java 21 + unidad systemd).
- `configurar-realm.sh` — realm `morini`, cliente OIDC `proxmox`, grupos y mapeador de grupos.
- `alta-usuario.sh` — alta de un empleado (usuario + contraseña temporal + grupo) en un comando.

## Versiones probadas
Proxmox VE 9.2.3 · Keycloak 26.7.0 · Debian 13 (LXC) · OpenJDK 21

## ⚠️ Los dos fallos que te van a pasar

### 1) El usuario entra… y se queda SIN permisos (y no salta ningún error)

Keycloak envía los grupos con la **ruta completa** (`/pve-admins`), porque los grupos
pueden anidarse. Proxmox no admite barras en un nombre de grupo, así que **lo descarta en
silencio**. Solo lo verás en el journal:

```
openid group '/pve-admins' contains invalid characters
```

**Arreglo:** en el mapeador de grupos del cliente, `full.path = false`.
Es el valor por defecto de Keycloak, así que le pasa a todo el mundo.

```bash
CID=$(kcadm.sh get clients -r morini -q clientId=proxmox --fields id --format csv --noquotes)
MID=$(kcadm.sh get clients/$CID/protocol-mappers/models -r morini \
        --fields id,name --format csv --noquotes | grep grupos | cut -d, -f1)
kcadm.sh update clients/$CID/protocol-mappers/models/$MID -r morini \
        -s 'config."full.path"=false'
```

### 2) Proxmox NO crea el grupo con el nombre del claim

Le añade el **sufijo del realm**: `pve-admins` → `pve-admins-keycloak`.
Los roles se asignan a ESE nombre, no al de Keycloak.

```bash
pveum acl modify / -group pve-admins-keycloak     -role Administrator
pveum acl modify / -group pve-operadores-keycloak -role PVEVMAdmin
pveum acl modify / -group pve-auditores-keycloak  -role PVEAuditor
```

## Seguridad — léelo antes de copiar

- Los scripts llevan la contraseña de administración de Keycloak **en claro** para que
  el vídeo sea reproducible tal cual. **Cámbiala el primer día** y sácala a una variable
  de entorno o a un gestor de secretos.
- El laboratorio usa Keycloak en `start-dev` sobre **HTTP**. En producción: `start`,
  base de datos externa, TLS y un nombre de dominio real (el emisor va firmado en los tokens).
- El token de sesión de `kcadm.sh` caduca; vuelve a hacer `config credentials` si te da 401.

## Lo mismo con otros proveedores

OpenID Connect es un estándar: sirve igual con **Authentik**, **Microsoft Entra ID** o
**Google Workspace**. Cambian la URL del emisor y cómo se emite el claim de grupos.
