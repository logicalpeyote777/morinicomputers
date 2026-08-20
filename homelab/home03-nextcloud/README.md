# home03 — Nextcloud en serio: Postgres + Redis + cron dedicado

Ficheros del tutorial «Nextcloud con Postgres y Redis: de 72s a 12s» de
Morini Computers (YouTube).

| Fichero | Qué es |
|---|---|
| `simple.yml` | El compose de tres líneas que circula por medio internet (SQLite, sin caché, sin cron): **el punto de partida** |
| `docker-compose.yml` | El montaje en serio: Postgres + Redis + app + contenedor de cron, dos redes y healthchecks encadenados |
| `instalar.sh` | Instalación repetible por `occ`: base de datos, dominios de confianza, las **tres** claves de `memcache` y `background:cron` |
| `bench.sh` | Banco de pruebas: 8 clientes subiendo a la vez por WebDAV (lo que hace el cliente de escritorio) |
| `comparar.sh` | Pone las dos mediciones una al lado de la otra |

## La medición del vídeo

Misma máquina, mismos ficheros, 24 subidas simultáneas (8 clientes × 3 ficheros de 256 KB):

| Montaje | Tiempo | Ficheros/s |
|---|---|---|
| `simple.yml` — SQLite, sin caché, sin cron | 72,6 s | 0,3 |
| `docker-compose.yml` — Postgres + Redis + cron | **12,2 s** | **2,0** |

→ **5,9 veces más rápido.** Mismo hardware; cambia lo que hay debajo.

## Las tres piezas, y por qué

- **Postgres, no SQLite.** SQLite bloquea el fichero entero para escribir: dos
  clientes sincronizando no van en paralelo, van en fila india. El propio
  Nextcloud lo desaconseja «especialmente si usas el cliente de escritorio».
- **Redis son TRES cosas, no una.** `memcache.local` (APCu, este proceso),
  `memcache.distributed` (compartida) y `memcache.locking` — esta última saca
  los cerrojos de fichero de la base de datos, y es la que casi nadie configura.
- **Un contenedor de cron.** En el modo por defecto las tareas de fondo sólo
  corren cuando alguien abre el navegador: la papelera no se vacía, los enlaces
  compartidos no caducan y las miniaturas no se generan.

## Dos avisos

- `depends_on` a secas sólo espera a que el contenedor **exista**. El cron
  necesita `condition: service_healthy`, o arranca antes de que la aplicación
  haya desplegado su código y muere sin ejecutar nada.
- Si ya tienes Nextcloud sobre SQLite, **cambiar el compose no migra nada**:
  esas variables sólo se leen en la primera instalación, después manda
  `config.php`. Se migra con `occ db:convert-type`.

Laboratorio aislado y propio; solo fines educativos. Las contraseñas que
aparecen son **falsas**.
