#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/graphic-monitor.xcodeproj"
SCHEME="graphic-monitor"
CONFIGURATION="Release"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP_NAME="graphic-monitor.app"
BUILD_PRODUCT="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME"
EXPORT_DIR="$ROOT_DIR/dist"
INSTALL_PATH="/Applications/$APP_NAME"

SKIP_BUILD=false
SKIP_INSTALL=false
SKIP_OPEN=false
VERBOSE=false

usage() {
    cat <<EOF
Uso: $(basename "$0") [opciones]

Compila graphic-monitor en Release, exporta el .app a dist/ e instala en /Applications.

Opciones:
  --skip-build     No compilar; usar el .app ya generado en build/DerivedData
  --no-install     Solo compilar y exportar a dist/ (no copiar a /Applications)
  --no-open        No abrir la app después de instalar
  --verbose        Mostrar toda la salida de xcodebuild
  -h, --help       Mostrar esta ayuda
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-build) SKIP_BUILD=true ;;
        --no-install) SKIP_INSTALL=true ;;
        --no-open) SKIP_OPEN=true ;;
        --verbose) VERBOSE=true ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Opción desconocida: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

step() {
    echo ""
    echo "[$1/$TOTAL_STEPS] $2"
}

show_running_processes() {
    local pids
    pids="$(pgrep -x graphic-monitor 2>/dev/null || true)"
    if [[ -z "$pids" ]]; then
        echo "  Sin procesos graphic-monitor en ejecución"
        return 1
    fi
    echo "  Procesos en ejecución:"
    while IFS= read -r pid; do
        ps -p "$pid" -o pid=,etime=,command= 2>/dev/null | sed 's/^/    /'
    done <<< "$pids"
}

terminate_graphic_monitor() {
    local attempt
    for attempt in 1 2 3 4 5; do
        show_running_processes || return 0
        echo "  Cerrando instancias (intento $attempt/5)..."
        pkill -x graphic-monitor 2>/dev/null || true
        sleep 1
    done
    if show_running_processes; then
        echo "  Advertencia: quedaron procesos activos; ciérralos manualmente si hace falta" >&2
    fi
}

filter_xcodebuild_output() {
    local line
    while IFS= read -r line; do
        if [[ "$line" == SwiftCompile*Compiling\ * ]]; then
            local files
            files="$(sed -E 's/^SwiftCompile[^C]*Compiling\\? //; s/ \/.*//' <<< "$line" | tr '\\' ' ')"
            echo "  Compilando: $files"
        elif [[ "$line" == CompileSwift* ]]; then
            echo "  Compilando fuentes Swift..."
        elif [[ "$line" == Ld\ * ]]; then
            echo "  Enlazando binario..."
        elif [[ "$line" == CodeSign* ]]; then
            echo "  Firmando app..."
        elif [[ "$line" == "** BUILD SUCCEEDED **" ]]; then
            echo "  Build exitoso"
        elif [[ "$line" == "** BUILD FAILED **" ]]; then
            echo "  Build fallido" >&2
        elif [[ "$line" == error:* || "$line" == *"error:"* ]]; then
            echo "  $line" >&2
        fi
    done
}

run_xcodebuild() {
    local log_file
    log_file="$(mktemp)"
    trap 'rm -f "$log_file"' RETURN

    set +e
    if [[ "$VERBOSE" == true ]]; then
        xcodebuild \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -configuration "$CONFIGURATION" \
            -derivedDataPath "$DERIVED_DATA" \
            build 2>&1 | tee "$log_file"
    else
        xcodebuild \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -configuration "$CONFIGURATION" \
            -derivedDataPath "$DERIVED_DATA" \
            build 2>&1 | tee "$log_file" | filter_xcodebuild_output
    fi
    local status=${PIPESTATUS[0]}
    set -e

    if [[ $status -ne 0 ]]; then
        echo "" >&2
        echo "Error de compilación. Últimas líneas del log:" >&2
        tail -20 "$log_file" >&2
        echo "" >&2
        echo "Ejecuta con --verbose para ver el log completo." >&2
        exit $status
    fi

    if ! grep -q "SwiftCompile\|CompileSwift\|Ld " "$log_file"; then
        echo "  Sin cambios; el build ya estaba al día"
    fi
}

if [[ -d "/Applications/Xcode.app" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
else
    echo "Error: no se encontró Xcode en /Applications/Xcode.app" >&2
    echo "Instala Xcode desde la App Store o ajusta DEVELOPER_DIR." >&2
    exit 1
fi

TOTAL_STEPS=3
if [[ "$SKIP_BUILD" == true ]]; then
    TOTAL_STEPS=2
fi
if [[ "$SKIP_INSTALL" == true ]]; then
    TOTAL_STEPS=$((TOTAL_STEPS - 1))
fi

CURRENT_STEP=0

if [[ "$SKIP_BUILD" == false ]]; then
    CURRENT_STEP=$((CURRENT_STEP + 1))
    step "$CURRENT_STEP" "Compilando $SCHEME ($CONFIGURATION)..."
    run_xcodebuild
    echo "✓ Compilación completada"
else
    echo "→ Omitiendo compilación (--skip-build)"
fi

if [[ ! -d "$BUILD_PRODUCT" ]]; then
    echo "Error: no se encontró $BUILD_PRODUCT" >&2
    exit 1
fi

CURRENT_STEP=$((CURRENT_STEP + 1))
step "$CURRENT_STEP" "Exportando a $EXPORT_DIR/$APP_NAME..."
rm -rf "$EXPORT_DIR/$APP_NAME"
mkdir -p "$EXPORT_DIR"
ditto "$BUILD_PRODUCT" "$EXPORT_DIR/$APP_NAME"
echo "✓ Exportado: $EXPORT_DIR/$APP_NAME"

if [[ "$SKIP_INSTALL" == false ]]; then
    CURRENT_STEP=$((CURRENT_STEP + 1))
    step "$CURRENT_STEP" "Instalando en $INSTALL_PATH..."
    terminate_graphic_monitor
    rm -rf "$INSTALL_PATH"
    ditto "$BUILD_PRODUCT" "$INSTALL_PATH"
    echo "✓ Instalado en $INSTALL_PATH"
fi

if [[ "$SKIP_OPEN" == false && "$SKIP_INSTALL" == false ]]; then
    echo ""
    echo "→ Abriendo la app..."
    open "$INSTALL_PATH"
fi

echo ""
echo "Listo."
