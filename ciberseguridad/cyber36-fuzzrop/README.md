# cyber36 — Fuzzing con AFL++ / AddressSanitizer y cadena ROP (NX + ASLR)

Código del tutorial **«Fuzzing: tu software a medida cae en 1 segundo»** de
[Morini Computers](https://github.com/logicalpeyote777/morinicomputers).

⚠️ **Solo para tu propio laboratorio aislado.** Todo esto se grabó contra un programa escrito y
compilado por nosotros, dentro de una red de laboratorio sin salida a internet. Auditar o atacar
software o sistemas ajenos sin autorización expresa por escrito es un delito.

## Ficheros

| Fichero | Qué es |
|---|---|
| `licencia.c` | El programa vulnerable: un validador de licencias «a medida» con un `memcpy` que no comprueba el tamaño (línea 28). |
| `exploit.py` | Cadena ROP con pwntools: fuga de libc con el `printf` del propio programa → `system("/bin/sh")`. Salta NX y ASLR. |
| `auditar.sh` | Revisa las protecciones de compilación de un binario propio y te dice qué bandera de gcc te falta. |
| `facturas_clientes.db` | El «botín» del vídeo. **Datos totalmente ficticios.** |

## Reproducirlo

```bash
# 1) build vulnerable (como una herramienta interna heredada)
gcc -g -O0 -fno-stack-protector -no-pie -z noexecstack -o licencia licencia.c
checksec --file=./licencia            # NX enabled, No canary, No PIE
cat /proc/sys/kernel/randomize_va_space   # 2 = ASLR al máximo

# 2) fuzzing con AFL++  — AFL_DONT_OPTIMIZE=1 ES OBLIGATORIO (ver abajo)
AFL_DONT_OPTIMIZE=1 afl-clang-fast -g -O0 -fno-stack-protector -no-pie -z noexecstack \
  -o licencia_fuzz licencia.c
mkdir -p entradas && printf "PYME-2026-ABCD-1234" > entradas/licencia_valida.txt
afl-fuzz -i entradas -o salida -- ./licencia_fuzz     # primer crash en ~0,13 s

# 3) AddressSanitizer → la línea exacta
clang -g -O0 -fsanitize=address -o licencia_asan licencia.c
./licencia_asan < salida/default/crashes/id:000000*   # stack-buffer-overflow licencia.c:28

# 4) el exploit
python3 exploit.py

# 5) la defensa
gcc -g -O2 -fstack-protector-strong -D_FORTIFY_SOURCE=2 -pie -fPIE \
  -Wl,-z,relro,-z,now -o licencia_seguro licencia.c
./auditar.sh licencia ; ./auditar.sh licencia_seguro
```

## Dos trampas que cuestan horas

1. **`afl-clang-fast` compila a `-O3` por su cuenta y el optimizador BORRA el bug.** Diez minutos,
   1.284.020 ejecuciones, cero crashes. Con `AFL_DONT_OPTIMIZE=1`: primer crash a los 128 ms.
   Regla de oro: **antes de fuzzear, comprueba a mano que el binario instrumentado peta con una
   entrada que sabes que peta.** Si no, estás fuzzeando otro programa.

2. **`pop rdi ; ret` ya no existe en el binario.** Desde glibc 2.34 desapareció `__libc_csu_init`,
   así que el ROP «de tutorial» no se puede reproducir tal cual. Aquí se usan como gadgets los
   propios *call-sites* de `validar()` (que dan lectura y escritura arbitrarias controlando `rbp`),
   y el `pop rdi` definitivo sale **de libc**, ya localizada gracias a la fuga.

## La defensa, en una línea

```c
if (n > (ssize_t)sizeof(clave)) n = sizeof(clave);   /* comprueba ANTES de copiar */
memcpy(clave, entrada, n);
```

…y compila siempre con `-fstack-protector-strong -D_FORTIFY_SOURCE=2 -pie -fPIE -Wl,-z,relro,-z,now`.
