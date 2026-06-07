#!/usr/bin/env bash
# ============================================================
#  Mp3Tag Tools for DoubleCMD - Linux/macOS Installer
#  Requirements: Python 3, DoubleCMD
# ============================================================

set -e

echo ""
echo " ============================================="
echo "  Mp3Tag Tools for DoubleCMD - Installer"
echo " ============================================="
echo ""

# ---- Check Python ----
if ! command -v python3 &>/dev/null; then
    echo "ERROR: Python 3 not found."
    echo "Install Python 3 using your package manager."
    exit 1
fi
echo "Python: $(python3 --version)"

# ---- Choose install folder ----
DEFAULT_DIR="$HOME/Mp3TagTools"
echo ""
echo "Where do you want to install the scripts?"
echo "Press ENTER to use the default: $DEFAULT_DIR"
read -r -p "> " INSTALL_DIR
if [ -z "$INSTALL_DIR" ]; then
    INSTALL_DIR="$DEFAULT_DIR"
fi

echo ""
echo "Install folder: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# ---- Copy scripts ----
echo "Copying files..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/tools/id3lib.py"        "$INSTALL_DIR/id3lib.py"
cp "$SCRIPT_DIR/tools/mp3tag_batch.py"  "$INSTALL_DIR/mp3tag_batch.py"
cp "$SCRIPT_DIR/tools/mp3tag_rename.py" "$INSTALL_DIR/mp3tag_rename.py"
chmod +x "$INSTALL_DIR/mp3tag_batch.py"
chmod +x "$INSTALL_DIR/mp3tag_rename.py"

# ---- Create wrapper shell scripts with fixed paths ----
cat > "$INSTALL_DIR/run_batch.sh" << WRAPPER
#!/usr/bin/env bash
TMPFILE="\$(mktemp /tmp/mp3tag_XXXXXX.txt)"
for f in "\$@"; do echo "\$f" >> "\$TMPFILE"; done
python3 "$INSTALL_DIR/mp3tag_batch.py" --filelist "\$TMPFILE"
rm -f "\$TMPFILE"
WRAPPER
chmod +x "$INSTALL_DIR/run_batch.sh"

cat > "$INSTALL_DIR/run_rename.sh" << WRAPPER
#!/usr/bin/env bash
TMPFILE="\$(mktemp /tmp/mp3tag_XXXXXX.txt)"
for f in "\$@"; do echo "\$f" >> "\$TMPFILE"; done
python3 "$INSTALL_DIR/mp3tag_rename.py" --filelist "\$TMPFILE"
rm -f "\$TMPFILE"
WRAPPER
chmod +x "$INSTALL_DIR/run_rename.sh"

echo ""
echo " ============================================="
echo "  Installation complete!"
echo " ============================================="
echo ""
echo " Folder: $INSTALL_DIR"
echo ""
echo " Configure DoubleCMD:"
echo " 1. Configuration > Options > Toolbar"
echo " 2. Add button 'External command':"
echo ""
echo "    BATCH TAG EDITOR:"
echo "      Command:    $INSTALL_DIR/run_batch.sh"
echo "      Parameters: %Lm"
echo ""
echo "    RENAME FROM TAGS:"
echo "      Command:    $INSTALL_DIR/run_rename.sh"
echo "      Parameters: %Lm"
echo ""
echo " 3. For tag columns use the audioinfo plugin"
echo "    already included in DoubleCMD:"
echo "    Configuration > Options > Files views > Columns"
echo "    Add columns from: Plugins > audioinfo"
echo ""
