# Mp3Tag Tools for DoubleCMD

A set of Python tools that bring [Mp3Tag](https://www.mp3tag.de/)-style
tag management directly into [DoubleCMD](https://doublecmd.sourceforge.io/),
the cross-platform file manager.

---

## Features

### Batch Tag Editor (`mp3tag_batch.py`)

A spreadsheet-style editor for ID3 tags across multiple MP3 files at once.

- Loads any number of MP3 files into a grid showing: **File, Title, Artist,
  Album, Year, Track, Genre, Comment**
- **Double-click** any cell to open an inline editor
- **"Apply to ALL files"** checkbox — change one field across every file
  in the list in a single operation (e.g. set the same Artist or Album
  for an entire album)
- **Add files** button to append more MP3s to the current session
- **Save all** writes ID3v2.3 + ID3v1 tags to every modified file
- Reads existing ID3v2 (UTF-8/UTF-16) and ID3v1 tags; writes ID3v2.3
  with UTF-8 encoding for full Unicode support

### Rename from Tags (`mp3tag_rename.py`)

Bulk-rename MP3 files using their ID3 tags with a live preview.

- **Pattern-based renaming** using variables substituted from the file's tags
- **Live preview** — the result column updates in real time as you type the pattern
- **Color-coded preview**: blue = will be renamed, gray = unchanged, red = conflict
- **Conflict detection** — warns about duplicate names before renaming

**Available pattern variables:**

| Variable   | Content                                | Example      |
|------------|----------------------------------------|--------------|
| `%title%`  | Track title                            | `Money`      |
| `%artist%` | Artist name                            | `Pink Floyd` |
| `%album%`  | Album name                             | `Dark Side`  |
| `%year%`   | Release year                           | `1973`       |
| `%track%`  | Track number (zero-padded to 2 digits) | `03`         |
| `%genre%`  | Genre name                             | `Rock`       |
| `%ext%`    | Original file extension                | `.mp3`       |

**Example patterns:**

```
%track% - %artist% - %title%             →  03 - Pink Floyd - Money.mp3
%artist% - %album% - %track% %title%     →  Pink Floyd - Dark Side - 03 Money.mp3
%year% - %album% - %track% - %title%     →  1973 - Dark Side - 03 - Money.mp3
```

---

## Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| DoubleCMD | 0.9+    | Windows, Linux, macOS, Android (proot) |
| Python    | 3.6+    | Must be in system PATH |
| tkinter   | —       | Bundled with Python on Windows/macOS; separate package on Linux |
| audioinfo | —       | Already bundled with DoubleCMD |

---

## Installation

### Windows

Double-click `install_windows.bat` (run as administrator if needed).

Then configure the DoubleCMD toolbar buttons with **Parameters: `%p`**.

### Linux / macOS

```bash
chmod +x install_linux_macos.sh
./install_linux_macos.sh
```

Then configure the DoubleCMD toolbar buttons with **Parameters: `%p`**.

### Android (Termux + proot-distro Ubuntu)

**Step 1 — Install Termux:X11** from the Termux add-ons repository and
start the X server before proceeding.

**Step 2 — Enter Ubuntu and install dependencies:**

```bash
proot-distro login ubuntu
sudo apt update && sudo apt install -y python3 python3-tk doublecmd-gtk
```

**Step 3 — Launch DoubleCMD once** (to generate its config file), then close it:

```bash
export DISPLAY=:0
doublecmd &
sleep 3
pkill doublecmd
```

**Step 4 — Run the Android installer inside proot:**

```bash
cd /path/to/mp3tag_dist/android
chmod +x install_android.sh
./install_android.sh
```

The installer will:
1. Copy the scripts to your chosen folder (default: `$HOME/Mp3TagTools`)
2. Create `run_batch.sh` and `run_rename.sh` wrappers
3. **Automatically add toolbar buttons** to `doublecmd.xml`

**Step 5 — Launch DoubleCMD:**

```bash
export DISPLAY=:0
doublecmd
```

---

## DoubleCMD Configuration (manual)

If the auto-installer does not find your config, add the buttons manually:

**Configuration → Options → Toolbar → Insert new button**

| Platform       | Command                              | Parameters |
|----------------|--------------------------------------|------------|
| Windows        | `cmd`                                | `/c "C:\path\to\run_batch.bat" %p` |
| Linux / macOS  | `/path/to/Mp3TagTools/run_batch.sh`  | `%p`       |
| Android/proot  | `$HOME/Mp3TagTools/run_batch.sh`     | `%p`       |

> **Note:** `%p` passes the full paths of selected files as individual
> arguments. Despite what the DoubleCMD documentation suggests, `%Lm`
> passes a temporary filelist that is deleted before the script can read
> it on all tested platforms (Windows, Android/proot GTK2).

---

## Typical Workflow

### Tagging an album from scratch

1. Navigate to the album folder in DoubleCMD
2. Select all MP3 files (`Ctrl+A` or `Num+`)
3. Click **Batch Tag Editor**
4. Double-click the **Artist** cell on any row, type the artist name,
   check **"Apply to ALL files"**, click OK
5. Do the same for **Album** and **Year**
6. Edit **Title** and **Track** individually for each file
7. Click **Save all**

### Renaming files after tagging

1. Select the MP3 files
2. Click **Rename from Tags**
3. Set the pattern, e.g. `%track% - %title%`
4. Check the preview (blue = will rename, red = conflict)
5. Click **Rename**

---

## File Structure

```
mp3tag_dist/
├── tools/
│   ├── id3lib.py           shared tag read/write library
│   ├── mp3tag_batch.py     batch tag editor
│   └── mp3tag_rename.py    rename from tags
├── android/
│   ├── install_android.sh      Android/proot installer
│   └── configure_doublecmd.py  auto-configures doublecmd.xml
├── install_windows.bat
├── install_linux_macos.sh
├── make_wrappers.py
└── README.md
```

After installation (example, install folder `Mp3TagTools`):

```
Mp3TagTools/
├── id3lib.py
├── mp3tag_batch.py
├── mp3tag_rename.py
├── run_batch.sh / run_batch.bat
└── run_rename.sh / run_rename.bat
```

---

## Technical Notes

- **ID3v2.3 write**: tags are written with UTF-8 encoding, supported by all
  modern players
- **ID3v1 compatibility**: an ID3v1 tag is always appended alongside ID3v2
- **Audio data preserved**: only the tag header is rewritten; the audio
  stream is never modified
- **No external dependencies**: pure Python standard library only
- **Atomic writes**: tag data is written to a temp file then swapped in with
  `os.replace()`, so a crash mid-write never corrupts the original file
- **proot/Termux:X11 compatibility**: the edit popup uses `lift()` +
  `focus_force()` instead of `grab_set()` for reliable focus handling
