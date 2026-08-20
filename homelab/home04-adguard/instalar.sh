#!/bin/bash
# Configuracion REPETIBLE de AdGuard Home: por su API, no por el asistente
# del navegador. Un fichero que se versiona y se vuelve a ejecutar dentro
# de dos anos, en otra maquina, y sale identico.
set -u
SETUP="http://10.10.10.10:3000"   # el puerto del asistente, solo la 1a vez
AGH="http://10.10.10.10:8090"     # el panel, atado a la IP de la red de casa
U="homelab"
P="clave-falsa-de-laboratorio"    # FALSA: esto es un laboratorio
J=(-sS -u "$U:$P" -H "Content-Type: application/json")

# 1 · el asistente entero, en UNA llamada (no en seis pantallas)
curl -sS -X POST "$SETUP/control/install/configure" \
  -H "Content-Type: application/json" -d "{
    \"web\": {\"ip\":\"10.10.10.10\", \"port\":8090},
    \"dns\": {\"ip\":\"10.10.10.10\", \"port\":53},
    \"username\":\"$U\", \"password\":\"$P\" }" >/dev/null \
  && echo "1/6 instalado, y atado SOLO a 10.10.10.10"
until curl -sf -o /dev/null -u "$U:$P" "$AGH/control/status"; do sleep 2; done

# 2 · el DNS. Aqui esta casi todo el criterio de este video:
#   tls://    -> el upstream va CIFRADO: tu operadora deja de ver que resuelves
#   bootstrap -> con que IP resuelvo el NOMBRE del servidor cifrado
#                (el huevo y la gallina del DNS cifrado)
#   nxdomain  -> "ese dominio no existe": el movil corta al instante.
#                Por defecto devuelve 0.0.0.0 y la app se queda esperando.
#   ratelimit -> 20 consultas/segundo POR CLIENTE es un problema el dia
#                que toda la casa llega por una sola IP (un router reenviando)
curl "${J[@]}" -X POST "$AGH/control/dns_config" -d '{
  "upstream_dns":  ["tls://1.1.1.1", "tls://9.9.9.9"],
  "bootstrap_dns": ["9.9.9.9", "1.1.1.1"],
  "blocking_mode": "nxdomain",
  "ratelimit": 0,
  "cache_size": 41943040,
  "cache_ttl_min": 60,
  "resolve_clients": true,
  "protection_enabled": true }' >/dev/null \
  && echo "2/6 DNS: upstream cifrado, NXDOMAIN, cache de 40 MB"

# 3 · las listas. DOS, y bien elegidas: mas listas no es mejor,
#     es mas falsos positivos y mas llamadas de "no me carga la web".
L=https://adguardteam.github.io/HostlistsRegistry/assets
curl "${J[@]}" -X POST "$AGH/control/filtering/config" \
     -d '{"enabled":true, "interval":24}' >/dev/null
for F in "AdGuard DNS filter:filter_1" "AdAway:filter_2"; do
  curl "${J[@]}" -X POST "$AGH/control/filtering/add_url" \
    -d "{\"name\":\"${F%%:*}\", \"url\":\"$L/${F##*:}.txt\",
         \"whitelist\":false}" >/dev/null
done
echo "3/6 dos listas anadidas"

# 4 · reglas PROPIAS: lo que ninguna lista publica sabe de TU casa.
#   ||dominio^                -> bloqueado para todos
#   ||dominio^$client=nombre  -> bloqueado solo para ESE equipo
#   @@||dominio^              -> excepcion: dejalo pasar aunque este en la lista
curl "${J[@]}" -X POST "$AGH/control/filtering/set_rules" -d '{"rules":[
  "! --- reglas propias del laboratorio ---",
  "||telemetria.tv-salon.lab.local^",
  "||tiktok.com^$client=tablet-ninos",
  "@@||ads.linkedin.com^" ]}' >/dev/null \
  && echo "4/6 reglas propias puestas"

# 5 · los clientes, con nombre. Esto SOLO funciona si AdGuard ve la IP real
#     de cada equipo: por eso el contenedor va en modo host.
for C in "tv-salon 10.10.10.21"     "movil-invitado 10.10.10.22" \
         "tablet-ninos 10.10.10.23" "portatil-trabajo 10.10.10.24"; do
  set -- $C
  curl "${J[@]}" -X POST "$AGH/control/clients/add" -d "{
    \"name\":\"$1\", \"ids\":[\"$2\"], \"use_global_settings\":true,
    \"use_global_blocked_services\":true, \"filtering_enabled\":true }" >/dev/null
done
echo "5/6 cuatro equipos de la casa, con nombre"

# 6 · el registro de consultas: 90 dias, sin anonimizar (es TU red)
curl "${J[@]}" -X POST "$AGH/control/querylog/config_update" \
     -d '{"enabled":true, "interval":2160, "anonymize_client_ip":false}' >/dev/null
curl "${J[@]}" -X POST "$AGH/control/filtering/refresh" \
     -d '{"whitelist":false}' >/dev/null
echo "6/6 registro de consultas activo"
