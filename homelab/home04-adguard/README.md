# home04 — AdGuard Home: bloqueo de publicidad y rastreo en el DNS

Ficheros del tutorial «AdGuard Home: el 46% de tu DNS es rastreo» de
Morini Computers (YouTube).

| Fichero | Qué es |
|---|---|
| `simple.yml` | El compose que circula: bridge + `ports: 53:53`. Arranca a la primera y te deja un **resolutor abierto en todas las interfaces** |
| `docker-compose.yml` | El montaje bueno: `network_mode: host`, atado a UNA dirección, volúmenes `conf/` y `work/` separados, versión fijada |
| `instalar.sh` | Configuración **repetible por la API**, no por el asistente del navegador: upstream cifrado, NXDOMAIN, listas, reglas propias, clientes con nombre y registro |
| `dominios.txt` | Los 50 dominios que contactan un móvil y un televisor en reposo |
| `comparar.sh` | La medición del vídeo: la misma lista contra un resolutor sin filtrar y contra AdGuard |
| `rafaga.sh` | 200 consultas simultáneas desde UNA sola IP (lo que ve AdGuard cuando el router reenvía el DNS de toda la casa) |
| `limite.sh` | Cambia `ratelimit` **sin destrozar el resto de la configuración** (ver abajo) |
| `filtrado.sh` | Bloqueado / legítimo / la excepción `@@\|\|` |
| `afinado.sh` | La caché (62 ms → 0 ms) y la regla por equipo (`$client=`) |
| `trafico.sh` + `registro.sh` | Genera tráfico desde 4 equipos y enseña el registro: quién preguntó qué |
| `cifrado.sh` | Por dónde sale de verdad la consulta (`tls://…:853`) |
| `fuga.sh` | El agujero: DNS sobre HTTPS del navegador se salta tu filtrado |

## La medición del vídeo

50 dominios, misma máquina, mismo momento:

| Resolutor | Resueltos | Bloqueados |
|---|---|---|
| `1.1.1.1` (sin filtrar) | 50 | 0 |
| AdGuard Home | 27 | **23** |

→ **46% de las consultas ni salen de casa.** Sin instalar nada en ningún equipo.

## Lo que no te cuentan

- **`ports: 53:53` publica en `0.0.0.0` y en IPv6**, en todas las interfaces —
  y Docker mete sus reglas *antes* que las de tu cortafuegos. Un resolutor DNS
  abierto se usa para amplificar ataques. Con `network_mode: host` lo atas a
  la IP de tu red y punto.
- **`ratelimit: 20` es el valor de fábrica, y es por segundo y POR CLIENTE.**
  Si tu router reenvía el DNS de la casa, para AdGuard la casa entera es UNA
  IP. Medido aquí: 200 consultas en ráfaga → **120 sin respuesta (60%)**, y
  **ni un error en el log**. Con `ratelimit: 0` → 200 de 200.
- **`POST /control/dns_config` REEMPLAZA la configuración entera.** Mandar sólo
  `{"ratelimit":0}` te resetea el upstream, el modo de bloqueo y la caché a los
  valores de fábrica. Hay que leer `dns_info`, tocar el campo y devolverla
  completa: es lo que hace `limite.sh`.
- **`blocking_mode: nxdomain`, no el `default`.** Por defecto contesta
  `0.0.0.0` y la app se queda esperando una conexión que no llega. Con NXDOMAIN
  corta al instante.
- **`bootstrap_dns` no es opcional** si usas `tls://` o `https://`: es la IP con
  la que resuelves el NOMBRE del servidor cifrado. Sin ella no arranca.
- **El DNS sobre HTTPS del navegador se salta todo esto.** Lo que lo frena es
  el dominio señuelo `use-application-dns.net`: si contestas que no existe,
  Firefox y Chrome entienden que la red filtra a propósito. AdGuard ya lo hace
  de fábrica. Al usuario que activa DoH a mano hay que pararlo en el cortafuegos.

## Uso

```bash
docker compose up -d
bash instalar.sh          # configuración completa por la API
bash comparar.sh          # la medición
```

Laboratorio aislado y propio (red `10.10.10.0/24`, host `homelab`, dominio
`lab.local`); solo fines educativos. Las contraseñas que aparecen son **falsas**.
