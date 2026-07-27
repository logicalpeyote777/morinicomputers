/* GestionPyme - validador de licencias (modulo legacy, 2011) */
#include <stdio.h>
#include <string.h>
#include <unistd.h>

char registro[65536];            /* registro de auditoria de intentos */

void banner(void)
{
    puts("=======================================");
    puts("  GestionPyme - validador de licencias");
    puts("  (c) Morini Computers S.L. - v1.4");
    puts("=======================================");
    printf("Introduce tu clave de licencia: ");
}

void validar(void)
{
    char clave[64];              /* clave de licencia del cliente */
    char entrada[512];           /* buffer de lectura desde stdin  */
    ssize_t n;

    n = read(0, entrada, sizeof(entrada));
    if (n <= 0)
        return;

    /* BUG: copiamos n bytes (hasta 512) dentro de 64 bytes */
    memcpy(clave, entrada, n);
    clave[63] = '\0';
    strncpy(registro, clave, 32);   /* auditoria del intento */

    if (strncmp(clave, "PYME-", 5) == 0)
        puts("Formato de clave reconocido.");
    else
        printf("Clave desconocida: %.20s\n", clave);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    banner();
    validar();
    puts("Licencia no valida.");
    return 0;
}
