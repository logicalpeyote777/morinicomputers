# home02 — Jellyfin con transcodificación por hardware

Ficheros del tutorial «Jellyfin: transcodificar por GPU, 14x menos CPU» de
Morini Computers (YouTube).

| Fichero | Qué es |
|---|---|
| `docker-compose.yml` | Jellyfin **sin** GPU: el punto de partida |
| `hw.yml` | El mismo, **con** los dos bloques que le dan la GPU (`devices` + `group_add`) |
| `setup-jellyfin.sh` | Completa el asistente de configuración por API |
| `biblioteca.sh` | Crea las bibliotecas (películas y series) por API |
| `bench.sh` | Mide la transcodificación por procesador y por GPU |
| `usuario.sh` | Crea un usuario con política restringida |

Laboratorio aislado y propio; solo fines educativos. Las contraseñas que
aparecen son **falsas**.
