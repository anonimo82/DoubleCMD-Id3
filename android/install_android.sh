#!/usr/bin/env bash
# ============================================================
#  Mp3Tag Tools for DoubleCMD - Android/proot-distro Installer
#  Requirements: proot-distro Ubuntu, Termux:X11, DoubleCMD GTK
#
#  Run this script INSIDE proot-distro Ubuntu:
#    proot-distro login ubuntu
#    cd /path/to/mp3tag_dist/android
#    chmod +x install_android.sh
#    ./install_android.sh
# ============================================================

set -e

echo ""
echo " ============================================="
echo "  Mp3Tag Tools for DoubleCMD"
echo "  Android / proot-distro Installer"
echo " ============================================="
echo ""

# ---- Check we are inside proot ----
if [ ! -f /etc/os-release ] || ! grep -qi ubuntu /etc/os-release 2>/dev/null; then
    echo "WARNING: This installer is designed for proot-distro Ubuntu."
    echo "If you are running a different distro, proceed with caution."
    echo ""
fi

# ---- Check Python ----
if ! command -v python3 &>/dev/null; then
    echo "ERROR: Python 3 not found."
    echo "Run: sudo apt update && sudo apt install -y python3 python3-tk"
    exit 1
fi
echo "Python: $(python3 --version)"

# ---- Check tkinter ----
if ! python3 -c "import tkinter" &>/dev/null; then
    echo ""
    echo "ERROR: Python tkinter not found."
    echo "Run: sudo apt install -y python3-tk"
    exit 1
fi
echo "tkinter: OK"

# ---- Check DoubleCMD ----
if ! command -v doublecmd &>/dev/null; then
    echo ""
    echo "WARNING: doublecmd not found in PATH."
    echo "Run: sudo apt install -y doublecmd-gtk"
    echo "Continuing installation anyway..."
    echo ""
fi

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
TOOLS_DIR="$(dirname "$SCRIPT_DIR")/tools"

if [ ! -f "$TOOLS_DIR/id3lib.py" ]; then
    TOOLS_DIR="$SCRIPT_DIR/../tools"
fi
if [ ! -f "$TOOLS_DIR/id3lib.py" ]; then
    echo "ERROR: Cannot find tools/ folder. Run from inside mp3tag_dist/android/"
    exit 1
fi

cp "$TOOLS_DIR/id3lib.py"        "$INSTALL_DIR/id3lib.py"
cp "$TOOLS_DIR/mp3tag_batch.py"  "$INSTALL_DIR/mp3tag_batch.py"
cp "$TOOLS_DIR/mp3tag_rename.py" "$INSTALL_DIR/mp3tag_rename.py"
chmod +x "$INSTALL_DIR/mp3tag_batch.py"
chmod +x "$INSTALL_DIR/mp3tag_rename.py"

# ---- Create wrapper shell scripts ----
# NOTE: On Android/proot DoubleCMD passes selected files via %p (full paths).
cat > "$INSTALL_DIR/run_batch.sh" << WRAPPER
#!/usr/bin/env bash
TMPFILE="\$(mktemp /tmp/mp3tag_XXXXXX.txt)"
for f in "\$@"; do
    echo "\$f" >> "\$TMPFILE"
done
python3 "$INSTALL_DIR/mp3tag_batch.py" --filelist "\$TMPFILE"
rm -f "\$TMPFILE"
WRAPPER
chmod +x "$INSTALL_DIR/run_batch.sh"

cat > "$INSTALL_DIR/run_rename.sh" << WRAPPER
#!/usr/bin/env bash
TMPFILE="\$(mktemp /tmp/mp3tag_XXXXXX.txt)"
for f in "\$@"; do
    echo "\$f" >> "\$TMPFILE"
done
python3 "$INSTALL_DIR/mp3tag_rename.py" --filelist "\$TMPFILE"
rm -f "\$TMPFILE"
WRAPPER
chmod +x "$INSTALL_DIR/run_rename.sh"

echo "Scripts installed."
echo ""

# ---- Auto-configure DoubleCMD toolbar ----
echo "Configuring DoubleCMD toolbar..."
python3 "$SCRIPT_DIR/configure_doublecmd.py" "$INSTALL_DIR"

echo ""
echo " ============================================="
echo "  Installation complete!"
echo " ============================================="
echo ""
echo " Folder: $INSTALL_DIR"
echo ""
echo " To launch DoubleCMD with X11:"
echo "   export DISPLAY=:0"
echo "   doublecmd"
echo ""
echo " Toolbar buttons added:"
echo "   - Batch Tag Editor  (Command: $INSTALL_DIR/run_batch.sh, Parameters: %p)"
echo "   - Rename from Tags  (Command: $INSTALL_DIR/run_rename.sh, Parameters: %p)"
echo ""
echo " IMPORTANT: Select MP3 files in DoubleCMD using Num+ or Ctrl+Click"
echo " before clicking the toolbar buttons."
echo ""
