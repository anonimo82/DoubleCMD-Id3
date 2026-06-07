#!/usr/bin/env bash
# ============================================================
#  Mp3Tag Tools per DoubleCMD - Installer Linux/macOS
#  Requisiti: Python 3, DoubleCMD
# ============================================================

set -e

echo ""
echo " ============================================="
echo "  Mp3Tag Tools per DoubleCMD - Installer"
echo " ============================================="
echo ""

# ---- Verifica Python ----
if ! command -v python3 &>/dev/null; then
    echo "ERRORE: Python 3 non trovato."
    echo "Installa Python 3 con il tuo package manager."
    exit 1
fi
echo "Python: $(python3 --version)"

# ---- Scegli cartella ----
DEFAULT_DIR="$HOME/Mp3TagTools"
echo ""
echo "Dove vuoi installare gli script?"
echo "Premi INVIO per usare il default: $DEFAULT_DIR"
read -r -p "> " INSTALL_DIR
if [ -z "$INSTALL_DIR" ]; then
    INSTALL_DIR="$DEFAULT_DIR"
fi

echo ""
echo "Cartella di installazione: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# ---- Copia gli script ----
echo "Copio i file..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/tools/id3lib.py"        "$INSTALL_DIR/id3lib.py"
cp "$SCRIPT_DIR/tools/mp3tag_batch.py"  "$INSTALL_DIR/mp3tag_batch.py"
cp "$SCRIPT_DIR/tools/mp3tag_rename.py" "$INSTALL_DIR/mp3tag_rename.py"
chmod +x "$INSTALL_DIR/mp3tag_batch.py"
chmod +x "$INSTALL_DIR/mp3tag_rename.py"

# ---- Crea wrapper shell con percorso fisso ----
cat > "$INSTALL_DIR/run_batch.sh" << EOF
#!/usr/bin/env bash
TMPFILE="\$(mktemp /tmp/mp3tag_XXXXXX.txt)"
for f in "\$@"; do echo "\$f" >> "\$TMPFILE"; done
python3 "$INSTALL_DIR/mp3tag_batch.py" --filelist "\$TMPFILE"
rm -f "\$TMPFILE"
EOF
chmod +x "$INSTALL_DIR/run_batch.sh"

cat > "$INSTALL_DIR/run_rename.sh" << EOF
#!/usr/bin/env bash
TMPFILE="\$(mktemp /tmp/mp3tag_XXXXXX.txt)"
for f in "\$@"; do echo "\$f" >> "\$TMPFILE"; done
python3 "$INSTALL_DIR/mp3tag_rename.py" --filelist "\$TMPFILE"
rm -f "\$TMPFILE"
EOF
chmod +x "$INSTALL_DIR/run_rename.sh"

echo ""
echo " ============================================="
echo "  Installazione completata!"
echo " ============================================="
echo ""
echo " Cartella: $INSTALL_DIR"
echo ""
echo " Configura DoubleCMD:"
echo " 1. Configuration > Options > Toolbar"
echo " 2. Aggiungi pulsante 'External command':"
echo ""
echo "    BATCH EDITOR:"
echo "      Command:    $INSTALL_DIR/run_batch.sh"
echo "      Parameters: %Lm"
echo ""
echo "    RINOMINA DAI TAG:"
echo "      Command:    $INSTALL_DIR/run_rename.sh"
echo "      Parameters: %Lm"
echo ""
echo " 3. Per le colonne usa il plugin audioinfo"
echo "    gia incluso in DoubleCMD:"
echo "    Configuration > Options > Files views > Columns"
echo "    Aggiungi colonne da: Plugins > audioinfo"
echo ""
