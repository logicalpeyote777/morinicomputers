# home06 — SMART y smartd: entérate de que un disco se está muriendo ANTES

Scripts del tutorial «SMART dice PASSED y le queda el 19% de vida» de Morini Computers (YouTube).
Laboratorio limpio y propio (usuario `homelab`, sin hostnames ni números de serie); solo fines educativos.

## Qué hay aquí

| Fichero | Qué es |
|---|---|
| `salud.sh` | Lo que `smartctl -H` NO te dice, de todos los discos, de un vistazo: los 5 atributos que Backblaze correlaciona con fallo real, el pre-fail con más recorrido consumido y la temperatura. |
| `superficie.sh` | Mide la velocidad real del disco con `dd` y demuestra con números que el autotest **corto no lee tu superficie**: 1 minuto ≈ 0,3 % del disco. |
| `smartd.conf` | La configuración de vigilancia, un renglón por disco. **`-d sat`, nunca la salida de `--scan`.** |
| `aviso.sh` | A dónde va el aviso. `smartd` lo llama por `-M exec` y pasa todo por variables de entorno: sin servidor de correo. |

## Los 5 atributos que importan

| ID | Nombre | Qué significa |
|---|---|---|
| 5 | `Reallocated_Sector_Ct` | Sectores dados por perdidos y sustituidos por repuestos de fábrica. |
| 187 | `Reported_Uncorrect` | Lecturas que ni con corrección de errores se han recuperado. |
| 188 | `Command_Timeout` | Órdenes que el disco no contestó a tiempo. **Raw empaquetado**: `4295032833` = `0x0000000100010001` = tres contadores de 1. |
| 197 | `Current_Pending_Sector` | Sectores leídos mal y pendientes de decisión. **El más importante: está pasando ahora.** |
| 198 | `Offline_Uncorrectable` | Sectores irrecuperables encontrados fuera de línea. |

**Regla operativa:** el día que el 5 o el 197 dejan de ser cero, ese disco deja de guardar datos que
te importen. No cuando llegue al umbral — el día que deja de ser cero.

## Cómo se lee la tabla

`VALUE` es el valor **normalizado** (100 = nuevo, se lo inventa el fabricante), `THRESH` el umbral de
fallo y `RAW` el contador crudo. Se leen **juntos**: un RAW enorme no significa nada hasta saber cómo
lo empaqueta ese fabricante (11 millones de "errores de lectura" en un Seagate sano son operaciones,
no fallos), y un `VALUE` de 100 no dice nada si el atributo que se está gastando es otro.

Cuánto se ha consumido de verdad un atributo pre-fail:  `(100 − VALUE) / (100 − THRESH)`.
Con `Wear_Leveling_Count` en 019 y umbral 010 → **90 % consumido**, y `smartctl -H` sigue diciendo `PASSED`.

## Instalación

```bash
sudo cp smartd.conf /etc/smartd.conf         # revisa las rutas de -M exec
sudo install -Dm755 aviso.sh /usr/local/bin/aviso-disco.sh
sudo smartd -c /etc/smartd.conf -q onecheck  # PRUÉBALO antes de arrancar el servicio
sudo systemctl restart smartd
```

## Las cuatro reglas del vídeo

1. `smartctl -H` es un semáforo de un bit: cuando dice `FAILED` ya has perdido datos. Mira la tabla.
2. **Nunca pegues la salida de `smartctl --scan`**: devuelve `-d scsi` para discos SATA, y en ese modo
   la salud dice siempre `OK` y la tabla de atributos sale vacía. Se arregla con `-d sat`.
3. El autotest **corto** no lee tu superficie. El 197 sólo aparece si alguien LEE el sector: programa
   el **extendido** de madrugada (`-s (S/../.././02|L/../../6/03)`).
4. El aviso no existe hasta que lo pruebas: `-M test` + `smartd -q onecheck`. Y avisa **una vez por
   condición** (estado en `/var/lib/smartmontools`); con `-M daily` insiste cada día.
