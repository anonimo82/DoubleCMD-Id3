# Mp3Tag Tools for DoubleCMD

Tools to manage MP3 ID3 tags directly from DoubleCMD,
with features similar to Mp3Tag:

- **Batch Tag Editor** — edit tags of multiple MP3 files in a grid,
  with the ability to apply a value to all files at once
- **Rename from Tags** — rename files using ID3 tags with a customizable
  pattern (e.g. `%track% - %artist% - %title%`) and live preview

---

## Requirements

- **DoubleCMD** 0.9+ (Windows, Linux, macOS)
- **Python 3.6+** installed and in PATH
- **audioinfo** WDX plugin (already included in DoubleCMD) to display
  tags as columns in the file panel

---

## Installation

### Windows

```
install_windows.bat
```

Run as administrator if needed. The script asks where to install
the scripts and shows the instructions to configure DoubleCMD.

### Linux / macOS

```bash
chmod +x install_linux_macos.sh
./install_linux_macos.sh
```

---

## DoubleCMD Configuration

### Toolbar buttons

After installation, add buttons in
**Configuration → Options → Toolbar → Insert new button**:

**Batch Tag Editor:**
- Type: External command
- Command: `cmd` (Windows) or path to `run_batch.sh` (Linux/macOS)
- Parameters: `/c "INSTALL_DIR\run_batch.bat" %Lm` (Windows)
  or `%Lm` (Linux/macOS)

**Rename from Tags:**
- Type: External command
- Command: `cmd` (Windows) or path to `run_rename.sh` (Linux/macOS)
- Parameters: `/c "INSTALL_DIR\run_rename.bat" %Lm` (Windows)
  or `%Lm` (Linux/macOS)

### ID3 tag columns (Artist, Album, etc.)

Use the **audioinfo** plugin already included in DoubleCMD:

1. **Configuration → Options → Files views → Columns → Custom columns**
2. Create a new column set (e.g. "Music")
3. Add columns by clicking `+` → **Plugin → audioinfo**:
   - Artist, Title, Album, Track, Genre, Comment, Year

---

## Usage

### Batch Tag Editor

1. Select one or more MP3 files in the DoubleCMD panel
2. Click the toolbar button
3. Double-click a cell to edit it
4. Check **"Apply to ALL files"** to change a field across all files at once
5. Click **Save all**

### Rename from Tags

1. Select the MP3 files to rename
2. Click the toolbar button
3. Set the rename pattern (e.g. `%track% - %artist% - %title%`)
4. Check the preview
5. Click **Rename**

**Pattern variables:**
`%title%` `%artist%` `%album%` `%year%` `%track%` `%genre%` `%ext%`

---

## File structure

```
Mp3TagTools/
├── tools/
│   ├── id3lib.py           ← shared tag read/write library
│   ├── mp3tag_batch.py     ← batch tag editor
│   └── mp3tag_rename.py    ← rename from tags
├── install_windows.bat     ← Windows installer
├── install_linux_macos.sh  ← Linux/macOS installer
└── README.md               ← this file
```
