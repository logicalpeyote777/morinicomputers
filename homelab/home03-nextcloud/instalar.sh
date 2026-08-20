#!/bin/bash
# instalar.sh — instalacion REPETIBLE por linea de ordenes: ni asistente web ni
# capturas de pantalla. Si manana rehaces el servidor, sale identico.
set -e
occ() { docker compose exec -T -u www-data app php occ "$@"; }

# 1 · la instalacion, contra Postgres
occ maintenance:install \
    --database pgsql --database-host db --database-name nextcloud \
    --database-user nextcloud --database-pass clave-falsa-de-laboratorio \
    --admin-user homelab --admin-pass clave-falsa-de-laboratorio

# 2 · por que nombre se le puede llamar (si no, "acceso no confiable")
occ config:system:set trusted_domains 1 --value=10.10.10.10
occ config:system:set trusted_domains 2 --value=nube.lab.local

# 3 · Redis: son TRES cosas distintas, no una
occ config:system:set memcache.local       --value='\OC\Memcache\APCu'   # esta maquina
occ config:system:set memcache.distributed --value='\OC\Memcache\Redis'  # compartida
occ config:system:set memcache.locking     --value='\OC\Memcache\Redis'  # los cerrojos
occ config:system:set redis host     --value=redis
occ config:system:set redis port     --value=6379 --type=integer
occ config:system:set redis password --value=redis-falsa-de-laboratorio

# 4 · el reloj: cron de verdad, no "cuando alguien abra el navegador"
occ background:cron

occ status
