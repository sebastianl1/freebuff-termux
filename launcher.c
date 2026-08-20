/*
 * Freebuff — Termux launcher
 *
 * Ejecuta el binario glibc de Freebuff (freebuff) dentro de la capa
 * glibc de Termux invocando el cargador dinámico glibc directamente:
 *
 *   ld-linux-aarch64.so.1 --library-path <glibc/lib> freebuff [args]
 *
 * PREFIX se inyecta en tiempo de compilación:
 *   cc -O2 -DPREFIX="\"$PREFIX\"" -o freebuff launcher.c
 *
 * A diferencia del wrapper bash, este launcher es nativo Android (Bionic)
 * y evita SIGSEGV cuando Node es padre, y evita "invalid ELF header"
 * por LD_LIBRARY_PATH con libc.so (script).
 *
 * Además configura:
 *   - FREEBUFF_BINARY_TARGET=linux-arm64
 *   - TMPDIR -> $PREFIX/tmp (no hay /tmp escribible en Android)
 *   - Limpia LD_PRELOAD/LD_LIBRARY_PATH que termux-exec inyecta
 */

#ifndef PREFIX
#define PREFIX "/data/data/com.termux/files/usr"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define GLIBC_LOADER PREFIX "/glibc/lib/ld-linux-aarch64.so.1"
#define GLIBC_LIB    PREFIX "/glibc/lib"
#define FREEBUFF_BIN PREFIX "/../home/.config/manicode/freebuff"
#define FREEBUFF_REAL_HOME "/data/data/com.termux/files/home/.config/manicode/freebuff"
#define TMP_DIR      PREFIX "/tmp"

int main(int argc, char **argv) {
    char **args;
    int i;
    const char *home;

    /* FREEBUFF necesita linux-arm64 explícito en Android */
    setenv("FREEBUFF_BINARY_TARGET", "linux-arm64", 1);

    /* TMPDIR para Bun y Freebuff (Android no tiene /tmp escribible) */
    if (!getenv("TMPDIR")) {
        setenv("TMPDIR", TMP_DIR, 1);
    }

    /* HOME para resolver ~/.config/manicode */
    home = getenv("HOME");
    if (!home) {
        home = "/data/data/com.termux/files/home";
        setenv("HOME", home, 1);
    }

    /* Limpiar LD_PRELOAD/LD_LIBRARY_PATH que termux-exec inyecta (Bionic).
     * El loader glibc intenta precargar libtermux-exec y falla. */
    unsetenv("LD_PRELOAD");
    unsetenv("LD_LIBRARY_PATH");

    /* Construir argv para: ld-linux-aarch64.so.1 freebuff [args] */
    args = calloc((size_t)argc + 3, sizeof(char *));
    if (!args) {
        perror("freebuff: calloc");
        return 127;
    }

    /* Usar ruta absoluta del binario (HOME puede variar) */
    const char *freebuff_bin = FREEBUFF_REAL_HOME;
    if (access(freebuff_bin, X_OK) != 0) {
        /* Fallback a $HOME/.config/manicode/freebuff */
        char *alt = malloc(512);
        if (alt) {
            snprintf(alt, 512, "%s/.config/manicode/freebuff", home);
            if (access(alt, X_OK) == 0) {
                freebuff_bin = alt;
            } else {
                free(alt);
            }
        }
    }

    args[0] = GLIBC_LOADER;
    args[1] = (char *)freebuff_bin;
    for (i = 1; i < argc; i++) {
        args[i + 1] = argv[i];
    }
    args[argc + 1] = NULL;

    execv(GLIBC_LOADER, args);
    perror("freebuff");
    return 127;
}
