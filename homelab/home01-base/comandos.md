# home01 — Una red por stack en Docker Compose

Todos los comandos del vídeo, en orden. Laboratorio: máquina Debian 13 `homelab`
en `10.10.10.0/24`, usuario `homelab`. Clientes, importes, IBAN y contraseñas
son **inventados**.

## 1. El problema (compose con `network_mode: bridge`)

```bash
# los dos stacks, con el 5432 publicado en 0.0.0.0
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}"

# ni una red propia: solo las tres de fábrica
docker network ls

# los cuatro contenedores, en la misma subred plana
docker network inspect bridge | jq -r '.[0].Containers[] | .Name + "  " + .IPv4Address' | sort

# un contenedor recién creado alcanza la base de datos del stack vecino
docker run --rm alpine nc -zv -w 5 172.17.0.2 5432

# y le lee la tabla entera
docker run --rm -e PGPASSWORD=clave-falsa-de-lab postgres:16-alpine \
  psql -h 172.17.0.2 -U facturas -d facturas -c "SELECT cliente, importe, iban FROM facturas;"

# el 5432 escuchando en 0.0.0.0 = abierto a toda la red local
sudo ss -lntp | grep -E "5432|808"
```

## 2. El arreglo (una red por stack)

```bash
cp aislado.yml docker-compose.yml && docker compose up -d   # en cada stack
docker network ls                                           # 2 redes por stack
```

Claves del `docker-compose.aislado.yml`:

- `name:` fija el nombre del proyecto → las redes se llaman siempre igual.
- `networks: frontend / backend` → dos capas, cada servicio solo en las que necesita.
- `backend: internal: true` → esa red **no tiene salida al exterior**.
- la base de datos **no publica ningún puerto** (`ports` sólo en la web).
- el puerto de la web se publica atado a una IP concreta, no a `0.0.0.0`.
- cambiar de red **no se aplica en caliente**: si no ves `Recreated`, no ha cambiado nada.

## 3. La prueba

```bash
# el MISMO ataque de antes -> Connection refused
docker run --rm -e PGCONNECT_TIMEOUT=5 -e PGPASSWORD=clave-falsa-de-lab postgres:16-alpine \
  psql -h 172.17.0.2 -U facturas -d facturas -c "SELECT * FROM facturas;"

# con la dirección NUEVA, desde el stack vecino -> CERRADO
docker compose exec web nc -z -w 5 172.18.0.2 5432 && echo ABIERTO || echo CERRADO

# dentro del stack, por nombre de servicio -> abierto (DNS interno de la red)
docker compose exec web nc -zv -w 5 db 5432

# la base de datos ya no sale a internet (internal: true)
docker exec facturas-db nc -z -w 5 1.1.1.1 443 && echo SALE || echo SIN SALIDA

# el 5432 ha desaparecido del host, y la web sigue respondiendo
sudo ss -lntp | grep -E "5432|808"
curl -sI http://10.10.10.10:8080 | head -3
```

## Aviso: Docker se salta tu cortafuegos

Publicar un puerto con `ports:` **ignora UFW**. Docker escribe sus reglas en la
cadena `DOCKER`, que se evalúa antes que las de UFW:

```bash
sudo ufw status            # Status: active — sólo 22/tcp permitido
nc -zv 10.10.10.10 5432    # desde otro equipo: open
```

Por eso una base de datos no lleva `ports`: lleva su red de stack con `internal: true`.
