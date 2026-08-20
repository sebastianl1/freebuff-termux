#!/data/data/com.termux/files/usr/bin/bash
#
# Freebuff — Termux
# Script de instalación para Termux
# v2.0.0
#
# Script creado por Sebastian Laguna (adaptado de claude-code-termux)
# https://github.com/sebastianl1/freebuff-termux
#
# Descripción:
#   Instala Freebuff de forma nativa en Termux: descarga el binario
#   oficial (build glibc linux-arm64) y lo ejecuta con un launcher
#   nativo Android a través de la capa glibc de Termux.
#   Multi-fuente: npm, descarga directa y caché local.
#   Sin proot, sin VMs.
#
# Uso:
#   bash install.sh              Instalación completa
#   bash install.sh --help       Muestra esta ayuda
#   bash install.sh --version    Muestra la versión
#   bash install.sh --uninstall  Desinstala freebuff
#

set -eEuo pipefail

# ── Configuración ────────────────────────────────────────────────────────────

SCRIPT_VERSION="2.0.0"
SCRIPT_AUTHOR="Sebastian Laguna"
SCRIPT_REPO="https://github.com/sebastianl1/freebuff-termux"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FREEBUFF_BIN_DIR="$PREFIX/bin"
FREEBUFF_SHARE_DIR="$PREFIX/share/freebuff"
FREEBUFF_REAL="$HOME/.config/manicode/freebuff"
FREEBUFF_META="$HOME/.config/manicode/freebuff-metadata.json"
GLIBC_PREFIX="$PREFIX/glibc"
GLIBC_LD="$GLIBC_PREFIX/lib/ld-linux-aarch64.so.1"
BACKUP_DIR="$HOME/backups/freebuff"
TMP_DIR="$PREFIX/tmp/freebuff-install"
LOG_FILE="$TMP_DIR/install.log"
INSTALL_FAILED=false
INSTALL_METHOD=""

# Fuentes del binario (por prioridad):
#   A. npm freebuff (latest)
#   B. Descarga directa codebuff.com
#   C. Caché local
NPM_PKG="freebuff"
MIRROR_DL="https://github.com/sebastianl1/freebuff-termux/releases/latest/download/freebuff-linux-arm64.tar.gz"
CACHE_DIR="$HOME/.cache/freebuff"

# ── Colores ─────────────────────────────────────────────────────────────────

BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BLUE="\033[34m"
WHITE="\033[97m"
RESET="\033[0m"

COLS=66

make_line() {
    local char="${1:-─}"
    local line=""
    printf -v line "%*s" "$COLS" ""
    echo "${line// /${char}}"
}

box_line() {
    echo -e "  ${BLUE}${BOLD}$1${RESET}"
}

box_text() {
    local content="$1"
    local color="${2:-}"
    local padding=$(( COLS - ${#content} - 2 ))
    printf "  ${BLUE}${BOLD}│${RESET} ${color}%s${RESET}%*s${BLUE}${BOLD}│${RESET}\n" "$content" "$padding" ""
}

section_header() {
    local title="$1"
    echo ""
    echo -e "  ${BLUE}${BOLD}◆ ${title}${RESET}"
    echo -e "  ${BLUE}${DIM}$(make_line)${RESET}"
    echo ""
}

check_item() {
    local label="$1"
    local status="$2"
    local detail="${3:-}"
    if [ "$status" = "ok" ]; then
        printf "  ${GREEN}✔${RESET} ${BOLD}%-34s${RESET}" "$label"
    elif [ "$status" = "skip" ]; then
        printf "  ${DIM}−${RESET} ${DIM}%-34s${RESET}" "$label"
    else
        printf "  ${YELLOW}⬡${RESET} ${BOLD}%-34s${RESET}" "$label"
    fi
    if [ -n "$detail" ]; then
        echo -e "${DIM}${detail}${RESET}"
    else
        echo ""
    fi
}

cleanup() {
    if [ "$INSTALL_FAILED" = "true" ] && [ -d "$BACKUP_DIR" ]; then
        restore_backup
    fi
    rm -rf "$TMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

print_error() {
    echo -e "\n  ${RED}${BOLD}ERROR${RESET} ${1}"
    exit 1
}

print_info() {
    echo -e "  ${DIM}${1}${RESET}"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-S}"
    local yn
    printf "  %s " "$prompt"
    if [ "$default" = "S" ]; then
        printf "${BOLD}[S/n]${RESET}: "
    else
        printf "${BOLD}[s/N]${RESET}: "
    fi
    read -r yn
    yn="${yn:-$default}"
    case "$yn" in
        [Ss]*) return 0 ;;
        *) return 1 ;;
    esac
}

run_hidden() {
    local desc="$1"
    shift
    mkdir -p "$TMP_DIR"
    printf "  ⬡ ${BOLD}%-34s${RESET}" "$desc"
    echo "--- [$desc] $(date) ---" >> "$LOG_FILE"
    "$@" >> "$LOG_FILE" 2>&1 &
    local pid=$!
    local spin='-\|/'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${WHITE}${BOLD}⬡${RESET} ${BOLD}%-34s${RESET} ${DIM}%s${RESET}" "$desc" "${spin:$i:1}"
        i=$(( (i + 1) % 4 ))
        sleep 0.1
    done
    local exit_code=0
    wait "$pid" || exit_code=$?
    printf "\r"
    if [ "$exit_code" -eq 0 ]; then
        printf "  ${GREEN}✔${RESET} ${BOLD}%-34s${RESET} ${GREEN}hecho${RESET}\n" "$desc"
    else
        printf "  ${RED}✘${RESET} ${BOLD}%-34s${RESET} ${RED}fallo${RESET}\n" "$desc"
        return "$exit_code"
    fi
}

show_log_tail() {
    echo ""
    echo -e "  ${DIM}Últimas líneas del log:${RESET}"
    tail -15 "$LOG_FILE" 2>/dev/null | while IFS= read -r line; do
        echo -e "  ${DIM}  ${line}${RESET}"
    done
}

print_banner() {
    echo ""
    box_line "┌$(make_line)┐"
    box_text "" ""
    box_text "Freebuff — Termux" "$WHITE${BOLD}"
    box_text "Script de instalación  v${SCRIPT_VERSION}" "${DIM}"
    box_text "" ""
    box_text "Sebastian Laguna" "${BOLD}"
    box_text "${SCRIPT_REPO}" "${DIM}"
    box_text "" ""
    box_line "├$(make_line)┤"
}

# ── Funciones del instalador ────────────────────────────────────────────────

check_environment() {
    section_header "Preparación"
    local env_ok=true
    local arch_ok=true
    if [ -n "${TERMUX_VERSION:-}" ]; then
        check_item "Entorno Termux" "ok" ""
    else
        check_item "Entorno Termux" "skip" ""
        env_ok=false
    fi
    if [ "$(uname -m)" = "aarch64" ]; then
        check_item "Arquitectura aarch64" "ok" ""
    else
        check_item "Arquitectura aarch64" "skip" "$(uname -m)"
        arch_ok=false
    fi
    if command -v node &>/dev/null; then
        local node_ver
        node_ver=$(node --version 2>/dev/null)
        check_item "Node.js" "ok" "$node_ver"
    else
        check_item "Node.js" "ok" "no requerido (opcional)"
    fi
    echo ""
    if [ "$env_ok" != "true" ] || [ "$arch_ok" != "true" ]; then
        print_error "Este instalador solo funciona en Termux ARM64 (aarch64)."
    fi
}

check_dependencies() {
    local missing=()
    local still=()
    local c
    local pkgs=""
    for c in curl tar file; do
        command -v "$c" &>/dev/null || missing+=("$c")
    done
    if ! command -v cc &>/dev/null && ! command -v clang &>/dev/null; then
        missing+=("clang")
    fi
    if [ "${#missing[@]}" -gt 0 ]; then
        for c in "${missing[@]}"; do
            pkgs="$pkgs $c"
        done
        echo -e "  ${YELLOW}⬡${RESET} Faltan herramientas: ${missing[*]}"
        if ! command -v pkg &>/dev/null; then
            print_error "Falta 'pkg' para instalarlas. Ejecuta: pkg install -y$pkgs"
        fi
        if ! run_hidden "Instalar dependencias" pkg install -y$pkgs; then
            run_hidden "Actualizar repositorios" pkg update -y || true
            run_hidden "Instalar dependencias" pkg install -y$pkgs || {
                show_log_tail
                print_error "No se pudieron instalar las herramientas. Ejecuta: pkg update && pkg install -y$pkgs"
            }
        fi
        for c in curl tar file; do
            command -v "$c" &>/dev/null || still+=("$c")
        done
        if ! command -v cc &>/dev/null && ! command -v clang &>/dev/null; then
            still+=("clang")
        fi
        if [ "${#still[@]}" -gt 0 ]; then
            print_error "Aún faltan herramientas: ${still[*]}."
        fi
    fi
    check_item "Dependencias requeridas" "ok" "curl tar clang file"
}

check_existing() {
    local current_version="$1"
    section_header "Estado actual"
    check_item "Freebuff" "ok" "$current_version"
    check_item "Origen" "ok" "$(command -v freebuff)"
    if ! ask_yes_no "¿Reinstalar Freebuff?" "N"; then
        print_info "Instalación omitida."
        return 1
    fi
}

backup_existing() {
    section_header "Respaldo"
    if [ -f "$FREEBUFF_REAL" ]; then
        mkdir -p "$BACKUP_DIR"
        local ts
        ts=$(date +%Y%m%d-%H%M%S)
        cp -a "$FREEBUFF_REAL" "$BACKUP_DIR/freebuff.backup.$ts" 2>/dev/null || true
        check_item "Respaldo binario" "ok" "$BACKUP_DIR/freebuff.backup.$ts"
    else
        check_item "Sin instalación previa" "ok" ""
    fi
}

restore_backup() {
    local backup_path
    backup_path=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'freebuff.backup.*' -print 2>/dev/null | sort -r | head -1 || true)
    if [ -n "$backup_path" ] && [ -f "$backup_path" ]; then
        cp -a "$backup_path" "$FREEBUFF_REAL" 2>/dev/null || true
        echo "--- [restore_backup] $(date) ---" >> "$LOG_FILE"
        echo "Binario restaurado desde $backup_path" >> "$LOG_FILE"
        echo -e "\n  ${YELLOW}⬡${RESET} Binario anterior restaurado." >&2
    fi
}

ensure_glibc_layer() {
    run_hidden "Recuperar dpkg interrumpido" dpkg --configure -a || {
        show_log_tail
        print_error "No se pudo recuperar dpkg. Ejecuta manualmente: dpkg --configure -a"
    }
    if [ ! -f "$PREFIX/etc/apt/sources.list.d/glibc.list" ]; then
        run_hidden "Actualizar repositorios" pkg update -y || {
            show_log_tail
            print_error "Falló 'pkg update'."
        }
        run_hidden "Agregar repositorio glibc" pkg install -y glibc-repo || {
            show_log_tail
            print_error "No se pudo agregar el repositorio glibc."
        }
        run_hidden "Actualizar repositorios" pkg update -y || {
            show_log_tail
            print_error "Falló 'pkg update'."
        }
    fi
    run_hidden "Instalar capa glibc" pkg install -y glibc ca-certificates 2>&1 | tail -5 || {
        show_log_tail
        print_error "No se pudo instalar la capa glibc."
    }
}

verify_binary() {
    local bin="$1"
    [ -f "$bin" ] || return 1
    [ "$(head -c 4 "$bin" | od -An -tx1 | tr -d ' \n')" = "7f454c46" ] || return 1
    local size
    size=$(wc -c < "$bin")
    [ "$size" -ge 100000000 ] || return 1
    file "$bin" 2>/dev/null | grep -qi 'aarch64' || return 1
    return 0
}

save_to_cache() {
    local src="$1"
    mkdir -p "$CACHE_DIR"
    cp "$src" "$CACHE_DIR/freebuff" 2>/dev/null || true
    chmod 755 "$CACHE_DIR/freebuff" 2>/dev/null || true
    sha256sum "$CACHE_DIR/freebuff" 2>/dev/null | awk '{print $1}' > "$CACHE_DIR/sha256" 2>/dev/null || true
}

cache_is_valid() {
    [ -f "$CACHE_DIR/freebuff" ] || return 1
    if [ -f "$CACHE_DIR/sha256" ]; then
        local expected actual
        expected=$(cat "$CACHE_DIR/sha256" 2>/dev/null)
        actual=$(sha256sum "$CACHE_DIR/freebuff" | awk '{print $1}')
        [ -n "$expected" ] && [ "$expected" = "$actual" ] || return 1
    fi
    verify_binary "$CACHE_DIR/freebuff"
}

install_binary() {
    local src="$1"
    if verify_binary "$src"; then
        mkdir -p "$(dirname "$FREEBUFF_REAL")"
        cp "$src" "$FREEBUFF_REAL"
        chmod 755 "$FREEBUFF_REAL"
        # Copiar tree-sitter si existe
        local wasm_src
        wasm_src=$(dirname "$src")/tree-sitter.wasm
        if [ -f "$wasm_src" ]; then
            cp -f "$wasm_src" "$HOME/.config/manicode/tree-sitter.wasm" 2>/dev/null || true
        fi
        return 0
    fi
    return 1
}

fetch_binary_from_npm() {
    local meta tarball
    # Intentar vía npm registry
    if ! command -v npm &>/dev/null; then
        return 1
    fi
    # Instalar paquete npm para obtener versión y luego descargar binario vía codebuff.com
    npm install -g freebuff --force 2>&1 | tail -5 || return 1
    local npm_version
    npm_version=$(node -p "require('$PREFIX/lib/node_modules/freebuff/package.json').version" 2>/dev/null) || return 1
    [ -n "$npm_version" ] || return 1
    # Descargar binario directo desde codebuff.com (el launcher npm lo haría, pero lo hacemos directo)
    local url="https://codebuff.com/api/releases/download/${npm_version}/freebuff-linux-arm64.tar.gz"
    local archive="$TMP_DIR/freebuff-linux-arm64.tar.gz"
    curl -fsSL --proto =https --retry 2 --connect-timeout 20 --max-time 600 -o "$archive" "$url" || return 1
    mkdir -p "$TMP_DIR/bin"
    tar -xzf "$archive" -C "$TMP_DIR/bin"
    verify_binary "$TMP_DIR/bin/freebuff"
}

fetch_binary_from_url() {
    local url="$1"
    local archive="$TMP_DIR/freebuff-linux-arm64.tar.gz"
    curl -fsSL --proto =https --retry 2 --connect-timeout 20 --max-time 600 -o "$archive" "$url" || return 1
    mkdir -p "$TMP_DIR/bin"
    tar -xzf "$archive" -C "$TMP_DIR/bin"
    verify_binary "$TMP_DIR/bin/freebuff"
}

install_launcher() {
    local launcher_src="$SCRIPT_DIR/launcher.c"
    if [ ! -f "$launcher_src" ]; then
        print_error "No se encontró 'launcher.c' junto a install.sh ($SCRIPT_DIR)."
    fi
    if ! run_hidden "Compilar launcher nativo" cc -O2 -DPREFIX="\"$PREFIX\"" -o "$FREEBUFF_BIN_DIR/freebuff" "$launcher_src"; then
        show_log_tail
        print_error "Falló la compilación del launcher nativo (requiere clang)."
    fi
    chmod 755 "$FREEBUFF_BIN_DIR/freebuff"
}

fetch_freebuff_binary() {
    mkdir -p "$(dirname "$FREEBUFF_REAL")"
    if run_hidden "Descargar binario (npm)" fetch_binary_from_npm; then
        install_binary "$TMP_DIR/bin/freebuff"
        INSTALL_METHOD="npm"
        save_to_cache "$TMP_DIR/bin/freebuff"
        return 0
    fi
    if run_hidden "Descargar binario (directo)" fetch_binary_from_url "https://codebuff.com/api/releases/download/0.0.152/freebuff-linux-arm64.tar.gz"; then
        install_binary "$TMP_DIR/bin/freebuff"
        INSTALL_METHOD="directo"
        save_to_cache "$TMP_DIR/bin/freebuff"
        return 0
    fi
    if cache_is_valid; then
        if install_binary "$CACHE_DIR/freebuff"; then
            INSTALL_METHOD="caché local"
            return 0
        fi
    fi
    show_log_tail
    print_error "Fallaron todas las fuentes de Freebuff. Revisa el log: $LOG_FILE"
}

install_freebuff() {
    section_header "Instalación"
    ensure_glibc_layer
    fetch_freebuff_binary
    install_launcher
}

verify_installation() {
    local version
    if version=$(freebuff --version 2>/dev/null); then
        check_item "Verificar instalación" "ok" "${version}"
    else
        # Fallback: verificar binario directo
        if [ -f "$FREEBUFF_REAL" ] && file "$FREEBUFF_REAL" 2>/dev/null | grep -q "ELF"; then
            version=$(cat "$FREEBUFF_META" 2>/dev/null | grep -oP '"version"\s*:\s*"\K[^"]+' || echo "desconocida")
            check_item "Verificar instalación" "ok" "binario $version"
        else
            print_error "La verificación de Freebuff falló."
        fi
    fi
}

print_summary() {
    local line
    printf -v line "%*s" "$COLS" ""
    line="${line// /─}"
    echo ""
    box_line "├$(make_line)┤"
    box_text "" ""
    box_text "  Instalación completada exitosamente" "${WHITE}${BOLD}"
    box_text "" ""
    box_line "└$(make_line)┘"
    echo ""
    echo -e "  ${BOLD}Comandos disponibles${RESET}"
    echo ""
    printf "    ${BOLD}%-26s${RESET} ${DIM}%s${RESET}\n" "freebuff" "Iniciar Freebuff (TUI interactiva)"
    printf "    ${BOLD}%-26s${RESET} ${DIM}%s${RESET}\n" "freebuff --version" "Versión instalada"
    printf "    ${BOLD}%-26s${RESET} ${DIM}%s${RESET}\n" "freebuff --help" "Ayuda y comandos"
    printf "    ${BOLD}%-26s${RESET} ${DIM}%s${RESET}\n" "bash install.sh" "Actualizar Freebuff"
    echo ""
    echo -e "  ${BOLD}Archivos instalados${RESET}"
    echo ""
    printf "    ${DIM}%-30s ${RESET}%s\n" "Origen:" "binario oficial glibc ($INSTALL_METHOD)"
    printf "    ${DIM}%-30s ${RESET}%s\n" "Launcher:" "$FREEBUFF_BIN_DIR/freebuff"
    printf "    ${DIM}%-30s ${RESET}%s\n" "Binario:" "$FREEBUFF_REAL"
    if [ -d "$BACKUP_DIR" ] && [ -n "$(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'freebuff.backup.*' -print -quit 2>/dev/null || true)" ]; then
        printf "    ${DIM}%-30s ${RESET}%s\n" "Respaldo:" "$BACKUP_DIR/"
    fi
    echo ""
    echo -e "  ${BOLD}Próximos pasos${RESET}"
    echo ""
    echo -e "  ${DIM}1.${RESET} ${BOLD}Iniciar Freebuff${RESET}"
    echo -e "     ${DIM}Ejecuta:${RESET}  freebuff"
    echo ""
    local sep
    printf -v sep "%*s" "$COLS" ""
    sep="${sep// /─}"
    echo -e "  ${DIM}${sep}${RESET}"
    echo -e "  ${BOLD}Script creado por Sebastian Laguna${RESET}"
    echo -e "  ${DIM}${SCRIPT_REPO}${RESET}"
    echo ""
}

do_uninstall() {
    echo ""
    box_line "┌$(make_line)┐"
    box_text "Desinstalar Freebuff" "$WHITE${BOLD}"
    box_line "└$(make_line)┘"
    echo ""
    if ! ask_yes_no "¿Está seguro de desinstalar Freebuff?" "N"; then
        echo -e "  ${DIM}Desinstalación cancelada.${RESET}"
        exit 0
    fi
    echo ""
    local removed=false
    if [ -f "$FREEBUFF_BIN_DIR/freebuff" ]; then
        echo -e "  ${GREEN}✔${RESET} Eliminando launcher: $FREEBUFF_BIN_DIR/freebuff"
        rm -f "$FREEBUFF_BIN_DIR/freebuff"
        removed=true
    fi
    if [ -f "$FREEBUFF_REAL" ]; then
        echo -e "  ${GREEN}✔${RESET} Eliminando binario: $FREEBUFF_REAL"
        rm -f "$FREEBUFF_REAL"
        rm -f "$FREEBUFF_META" 2>/dev/null || true
        removed=true
    fi
    if [ "$removed" = "false" ]; then
        echo -e "  ${YELLOW}−${RESET} No se encontró instalación de Freebuff."
    fi
    echo ""
    echo -e "  ${BOLD}Para eliminar respaldos:${RESET}"
    echo -e "  ${DIM}  rm -rf ${BACKUP_DIR}${RESET}"
    echo ""
    local sep
    printf -v sep "%*s" "$COLS" ""
    sep="${sep// /─}"
    echo -e "  ${DIM}${sep}${RESET}"
    echo -e "  ${BOLD}Script creado por Sebastian Laguna${RESET}"
    echo -e "  ${DIM}${SCRIPT_REPO}${RESET}"
    echo ""
    exit 0
}

show_help() {
    echo ""
    box_line "┌$(make_line)┐"
    box_text "Freebuff - Termux" "$WHITE${BOLD}"
    box_text "Script de instalación v${SCRIPT_VERSION}" ""
    box_line "└$(make_line)┘"
    echo ""
    echo -e "  ${BOLD}Uso:${RESET}"
    echo ""
    printf "  ${BOLD}%-28s${RESET} ${DIM}%s${RESET}\n" "bash install.sh" "Instalación completa"
    printf "  ${BOLD}%-28s${RESET} ${DIM}%s${RESET}\n" "bash install.sh --help" "Muestra esta ayuda"
    printf "  ${BOLD}%-28s${RESET} ${DIM}%s${RESET}\n" "bash install.sh --version" "Muestra la versión"
    printf "  ${BOLD}%-28s${RESET} ${DIM}%s${RESET}\n" "bash install.sh --uninstall" "Desinstala Freebuff"
    echo ""
    echo -e "  ${BOLD}Descripción:${RESET}"
    echo -e "  ${DIM}Instala Freebuff de forma nativa en Termux."
    echo -e "  ${DIM}Descarga el binario oficial glibc y lo lanza con un"
    echo -e "  ${DIM}launcher nativo Android vía la capa glibc de Termux."
    echo -e "  ${DIM}  - Fuentes: npm, descarga directa, caché"
    echo -e "  ${DIM}  - Nativo en Termux (sin proot)"
    echo -e "  ${DIM}  - Actualizar: re-ejecutar install.sh${RESET}"
    echo ""
    echo -e "  ${BOLD}Script creado por Sebastian Laguna${RESET}"
    echo -e "  ${DIM}${SCRIPT_REPO}${RESET}"
    echo ""
    exit 0
}

main() {
    case "${1:-}" in
        --help|-h) show_help ;;
        --version|-v) echo "freebuff-termux v${SCRIPT_VERSION}"; exit 0 ;;
        --uninstall) do_uninstall ;;
        "") ;;
        *) echo -e "  ${RED}[ERR]${RESET} Opción desconocida: ${1}"; echo "  Usa: bash install.sh --help"; exit 1 ;;
    esac
    print_banner
    if ! ask_yes_no "¿Deseas continuar con la instalación?" "S"; then
        echo -e "  ${DIM}Instalación cancelada.${RESET}"
        exit 0
    fi
    check_environment
    check_dependencies
    local current_version
    current_version=$(freebuff --version 2>/dev/null || echo "")
    if [ -n "$current_version" ] && ! check_existing "$current_version"; then
        exit 0
    fi
    backup_existing
    INSTALL_FAILED=true
    install_freebuff
    verify_installation
    INSTALL_FAILED=false
    print_summary
}

main "$@"
