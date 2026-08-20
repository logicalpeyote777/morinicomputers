# home05 — systemd .path e inotify: reaccionar en vez de sondear

Scripts del tutorial «Adiós cron: systemd .path reacciona en 0,06s» de Morini Computers (YouTube).
Laboratorio limpio y propio (red 10.10.10.0/24, host `homelab`, datos inventados); solo fines educativos.

## Qué hay aquí

| Fichero | Qué es |
|---|---|
| `procesar.sh` | El trabajo: vacía el buzón `entrada/`, archiva los `.csv` por fecha y aparta el resto a `rechazadas/`. **Vacía el directorio SIEMPRE** — lo que se queda dentro vuelve a disparar la unidad en bucle. |
| `procesar.service` | El servicio (`Type=oneshot`, `User=homelab`). **Sin `[Install]` a propósito**: no se habilita nunca. |
| `procesar.path` | El vigilante. `DirectoryNotEmpty` (ESTADO) en vez de `PathChanged` (EVENTO): lo que llega con la unidad parada no se pierde. Es el que se habilita. |
| `blindaje/limites.conf` | Drop-in para `procesar.service.d/`: `StartLimitIntervalSec=0`. Sin esto, una ráfaga de disparos deja la unidad en `failed` y deja de reaccionar para siempre. |
| `medir.sh` | Mide la latencia real: 4 entregas repartidas por todo el minuto, con mínimo, media y peor caso. |
| `comparar.sh` | La tabla cron vs .path a partir de las medidas reales. |
| `rafaga.sh` | 20 ficheros de golpe (un solo arranque del servicio, no veinte). |
| `lento.sh` | El FALLO: escribe dentro del buzón mientras el fichero crece → se procesa a trozos. |
| `atomico.sh` | El arreglo: escribe fuera y entra con `mv` (rename(2), atómico). |

## Instalación

```bash
sudo cp procesar.service procesar.path /etc/systemd/system/
sudo install -Dm644 blindaje/limites.conf /etc/systemd/system/procesar.service.d/limites.conf
sudo systemctl daemon-reload
sudo systemctl enable --now procesar.path      # el .path, NUNCA el .service
systemctl status procesar.path                 # active (waiting)
```

## Las cinco reglas del vídeo

1. Se habilita el `.path`, nunca el `.service`.
2. `DirectoryNotEmpty` (estado) sobrevive a un reinicio; `PathChanged` (evento) no.
3. El servicio vacía el directorio vigilado SIEMPRE, o entra en bucle.
4. Nunca se escribe dentro del directorio vigilado: se escribe fuera y se entra con `mv`.
5. `StartLimitIntervalSec=0` en un drop-in, o una ráfaga te deja el vigilante muerto y en silencio.

Medido en el laboratorio: cron `* * * * *` → 36,47 s de media (47 s el peor caso); `.path` → 0,06 s.
