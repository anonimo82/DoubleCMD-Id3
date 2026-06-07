#!/usr/bin/env bash
# build.sh – Compila entrambi i plugin Mp3Tag per DoubleCMD
# Uso: ./build.sh [debug]

set -e

LAZBUILD=$(which lazbuild 2>/dev/null || echo "")
OUTPUT_DIR="$(dirname "$0")/output"

# ---- Trova lazbuild ----
if [ -z "$LAZBUILD" ]; then
  # Posizioni comuni su Linux e macOS
  for CANDIDATE in \
      /usr/bin/lazbuild \
      /usr/local/bin/lazbuild \
      "$HOME/lazarus/lazbuild" \
      /opt/lazarus/lazbuild \
      /Applications/Lazarus/lazbuild; do
    if [ -x "$CANDIDATE" ]; then
      LAZBUILD="$CANDIDATE"
      break
    fi
  done
fi

if [ -z "$LAZBUILD" ]; then
  echo "ERRORE: lazbuild non trovato. Installa Lazarus o aggiungi lazbuild al PATH."
  exit 1
fi

echo "Usando: $LAZBUILD"
echo "Output: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# ---- Modalità debug o release ----
if [ "${1}" = "debug" ]; then
  BUILD_MODE="--build-mode=Debug"
  echo "Modalità: DEBUG"
else
  BUILD_MODE="--build-mode=Release"
  echo "Modalità: RELEASE"
fi

# ---- Compila Content Plugin (WDX) ----
echo ""
echo "=== Compilazione Content Plugin (WDX) ==="
"$LAZBUILD" $BUILD_MODE \
  --os="$TARGETOS" \
  content_plugin/Mp3TagWdx.lpi

# Individua il file generato (.so su Linux, .dylib su macOS)
WDX_SRC=$(find content_plugin -maxdepth 3 \( -name "*.so" -o -name "*.dylib" \) | head -1)
if [ -z "$WDX_SRC" ]; then
  echo "ERRORE: file .so/.dylib del WDX non trovato dopo la compilazione."
  exit 1
fi
cp "$WDX_SRC" "$OUTPUT_DIR/Mp3TagWdx.wdx"
echo "OK → $OUTPUT_DIR/Mp3TagWdx.wdx"

# ---- Compila DSX Plugin ----
echo ""
echo "=== Compilazione DSX Plugin ==="
"$LAZBUILD" $BUILD_MODE \
  --os="$TARGETOS" \
  dsx_plugin/Mp3TagDsx.lpi

DSX_SRC=$(find dsx_plugin -maxdepth 3 \( -name "*.so" -o -name "*.dylib" \) | head -1)
if [ -z "$DSX_SRC" ]; then
  echo "ERRORE: file .so/.dylib del DSX non trovato dopo la compilazione."
  exit 1
fi
cp "$DSX_SRC" "$OUTPUT_DIR/Mp3TagDsx.dsx"
echo "OK → $OUTPUT_DIR/Mp3TagDsx.dsx"

# ---- Riepilogo ----
echo ""
echo "=== Build completata ==="
ls -lh "$OUTPUT_DIR"
echo ""
echo "Installa i plugin in DoubleCMD:"
echo "  WDX: Configurazione → Plugins → WDX → Aggiungi → Mp3TagWdx.wdx"
echo "  DSX: Configurazione → Plugins → DSX → Aggiungi → Mp3TagDsx.dsx"
