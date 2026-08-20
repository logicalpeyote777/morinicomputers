# home02 — Jellyfin con transcodificación por hardware (VAAPI)

Todos los comandos del vídeo, en orden. Laboratorio: máquina Debian 13 `homelab`
en `10.10.10.0/24`, usuario `homelab`, GPU integrada Intel en `/dev/dri/renderD128`.
Las películas son ficheros generados para el vídeo y las contraseñas son **falsas**.

## 1. La biblioteca: el nombre del fichero ES el metadato

```bash
find /srv/media -type f -name '*.mkv' | sort
```

```
/srv/media/peliculas/El Ultimo Tren (2019)/El Ultimo Tren (2019) 1080p.mkv
/srv/media/peliculas/La Casa Vacia (2017)/La Casa Vacia (2017) 1080p.mkv
/srv/media/peliculas/Noche en el Puerto (2021)/Noche en el Puerto (2021) 1080p.mkv
/srv/media/series/Costa Norte/Season 01/Costa Norte S01E01.mkv
/srv/media/series/Costa Norte/Season 01/Costa Norte S01E02.mkv
```

Jellyfin no adivina: lee la ruta y el nombre. Carátulas locales: un `poster.jpg`
en la carpeta de cada película o serie.

## 2. Levantar el servicio

```bash
cat docker-compose.yml          # LÉELO antes de lanzarlo
docker compose up -d && docker compose ps
```

## 3. Configurar por API (repetible, sin tocar el navegador)

```bash
cat setup-jellyfin.sh  && bash setup-jellyfin.sh    # asistente
cat biblioteca.sh      && bash biblioteca.sh        # bibliotecas + token en ~/.jftok
```

Lo que ha reconocido:

```bash
curl -s "http://10.10.10.10:8096/Items?Recursive=true&IncludeItemTypes=Movie,Episode" \
  -H "Authorization: MediaBrowser Token=$(cat ~/.jftok)" \
  | jq -r '.Items[] | .Type + "  " + .Name'
```

## 4. El problema: transcodificar con la CPU

```bash
cat bench.sh && bash bench.sh cpu
```

```
== TRANSCODIFICANDO POR PROCESADOR (libx264) ==
   CPU del contenedor: 381.02%
   CPU del contenedor: 391.88%
   frame= 2250 fps= 50 q=-1.0 Lsize=N/A time=00:01:29.96 speed=2.01x
```

Cuatro núcleos al tope para UN solo espectador.

El contenedor todavía no ve la GPU:

```bash
docker exec jellyfin /usr/lib/jellyfin-ffmpeg/vainfo --display drm --device /dev/dri/renderD128
# Trying display: drm
# Failed to open the given device!
```

## 5. La solución: DOS bloques, no uno

```bash
diff docker-compose.yml hw.yml
```

```diff
+     # --- LOS DOS BLOQUES QUE LE DAN LA GPU AL CONTENEDOR ---
+     devices:
+       - /dev/dri/renderD128:/dev/dri/renderD128   # el nodo de render de la GPU
+     group_add:
+       - "992"                                     # GID del grupo 'render' DEL HOST
```

**`group_add` es el que casi nadie pone.** El nodo de render es `root:render` con
permisos `660`; el contenedor corre como `uid 1000`, que no está en ese grupo. Sin
esa línea el dispositivo está dentro del contenedor pero **no se puede abrir**, y
Jellyfin cae a software en silencio.

Averigua tu GID:

```bash
getent group render        # render:x:992:
```

Aplicar (hace falta **recrear** el contenedor, no vale un reload):

```bash
cp hw.yml docker-compose.yml && docker compose up -d     # -> "Recreated"
```

Comprobar que ahora sí la ve — busca `EncSlice` (= codificar) junto a tu códec:

```bash
docker exec jellyfin /usr/lib/jellyfin-ffmpeg/vainfo --display drm \
  --device /dev/dri/renderD128 2>&1 | grep -E "Driver version|H264(Main|High)"
```

```
vainfo: Driver version: Intel i965 driver for Intel(R) Sandybridge Mobile - 2.4.0.pre1
      VAProfileH264Main               : VAEntrypointVLD
      VAProfileH264Main               : VAEntrypointEncSlice
      VAProfileH264High               : VAEntrypointVLD
      VAProfileH264High               : VAEntrypointEncSlice
```

## 6. Decírselo a Jellyfin

Su API **no acepta cambios parciales**: se pide la configuración entera, se
modifica con `jq` y se devuelve entera. Esta técnica vale para todo Jellyfin.

```bash
J=http://10.10.10.10:8096; TOK=$(cat ~/.jftok)
curl -s "$J/System/Configuration/encoding" -H "Authorization: MediaBrowser Token=$TOK" \
 | jq '.HardwareAccelerationType="vaapi"' \
 | curl -s -X POST "$J/System/Configuration/encoding" \
        -H "Authorization: MediaBrowser Token=$TOK" \
        -H 'Content-Type: application/json' -d @- -w '\nHTTP %{http_code}\n'
```

## 7. El después

```bash
bash bench.sh gpu
```

```
== TRANSCODIFICANDO POR GPU (VAAPI) ==
   CPU del contenedor: 28.20%
   CPU del contenedor: 27.82%
   frame= 2250 fps=201 q=-0.0 Lsize=N/A time=00:01:30.00 speed=8.05x
```

**391,88% → 27,82% de CPU (14x menos). 50 → 201 fps (4x más rápido).**
Misma máquina, mismo fichero, misma orden.

## 8. La prueba de que Jellyfin la usa DE VERDAD

Pide el stream como lo pediría un móvil:

```bash
J=http://10.10.10.10:8096; TOK=$(cat ~/.jftok)
ID=$(curl -s "$J/Items?Recursive=true&IncludeItemTypes=Movie&Limit=1" \
      -H "Authorization: MediaBrowser Token=$TOK" | jq -r .Items[0].Id)
curl -s -o /dev/null -w 'HTTP %{http_code}  %{size_download} bytes\n' \
  "$J/Videos/$ID/stream.mp4?api_key=$TOK&static=false&VideoCodec=h264&MaxWidth=1280&VideoBitrate=3000000&DeviceId=movil-lab"
```

Y lee la orden que ha lanzado por dentro:

```bash
docker exec jellyfin sh -c 'ls -t /config/log/FFmpeg.Transcode-*.log | head -1 | xargs grep -m1 -h hwaccel' | fold -w 185
```

```
/usr/lib/jellyfin-ffmpeg/ffmpeg ... -init_hw_device vaapi=va:/dev/dri/renderD128,driver=i965
  -hwaccel vaapi -hwaccel_output_format vaapi -i file:"..." -codec:v:0 h264_vaapi
  -vf "...,scale_vaapi=w=1280:h=720:format=nv12,..." -b:v 3000000 ...
```

Si en esa línea **no** aparece `vaapi`, no está acelerando — por mucho que la
casilla esté marcada en el panel.

## 9. Usuarios con política restringida

```bash
cat usuario.sh && bash usuario.sh
```

```
invitado   admin=false   descargas=false   sesiones=2   tope_remoto=4000000
luca       admin=true    descargas=true    sesiones=0   tope_remoto=0
```
