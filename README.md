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
- Opens a **file selection dialog** when launched without arguments
- Reads ID3v2 + ID3v1 tags for maximum compatibility

**Available pattern variables:**

| Variable   | Content                            | Example         |
|------------|------------------------------------|-----------------|
| `%title%`  | Track title                        | `Money`         |
| `%artist%` | Artist name                        | `Pink Floyd`    |
| `%album%`  | Album name                         | `Dark Side`     |
| `%year%`   | Release year                       | `1973`          |
| `%track%`  | Track number (zero-padded to 2 digits) | `03`        |
| `%genre%`  | Genre name                         | `Rock`          |
| `%ext%`    | Original file extension            | `.mp3`          |

**Example patterns:**

```
%track% - %artist% - %title%       →  03 - Pink Floyd - Money.mp3
%artist% - %album% - %track% %title%  →  Pink Floyd - Dark Side - 03 Money.mp3
%year% - %album% - %track% - %title%  →  1973 - Dark Side - 03 - Money.mp3
```

### Tag columns in DoubleCMD (via audioinfo plugin)

DoubleCMD ships with the **audioinfo** WDX plugin which displays ID3 tags
as sortable columns in the file panel — no additional installation needed.
Supported fields: Artist, Title, Album, Track, Year, Genre, Comment,
Bitrate, Duration, Sample rate, and more.

---

## Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| DoubleCMD | 0.9+    | Windows, Linux, macOS |
| Python    | 3.6+    | Must be in system PATH |
| audioinfo | —       | Already bundled with DoubleCMD |

---

## Installation

### Windows

Double-click `install_windows.bat` (run as administrator if needed).

The installer will:
1. Check that Python 3 is available
2. Ask where to install the scripts (default: `%USERPROFILE%\Mp3TagTools`)
3. Copy all scripts to the chosen folder
4. Create `run_batch.bat` and `run_rename.bat` wrapper scripts
5. Print the exact DoubleCMD toolbar configuration to use

### Linux / macOS

```bash
chmod +x install_linux_macos.sh
./install_linux_macos.sh
```

The installer does the same as above, creating `run_batch.sh` and
`run_rename.sh` wrapper scripts in the chosen folder.

---

## DoubleCMD Configuration

### Step 1 — Add toolbar buttons

Go to **Configuration → Options → Toolbar → Insert new button** and add:

**Batch Tag Editor:**

| Field      | Windows value                                      | Linux/macOS value                  |
|------------|----------------------------------------------------|------------------------------------|
| Type       | External command                                   | External command                   |
| Command    | `cmd`                                              | `/path/to/Mp3TagTools/run_batch.sh`|
| Parameters | `/c "C:\path\to\Mp3TagTools\run_batch.bat" %Lm`   | `%Lm`                              |
| Tooltip    | `Batch Tag Editor`                                 | `Batch Tag Editor`                 |

**Rename from Tags:**

| Field      | Windows value                                       | Linux/macOS value                   |
|------------|-----------------------------------------------------|-------------------------------------|
| Type       | External command                                    | External command                    |
| Command    | `cmd`                                               | `/path/to/Mp3TagTools/run_rename.sh`|
| Parameters | `/c "C:\path\to\Mp3TagTools\run_rename.bat" %Lm`   | `%Lm`                               |
| Tooltip    | `Rename from Tags`                                  | `Rename from Tags`                  |

> **Note:** `%Lm` is a DoubleCMD variable that expands to the list of
> currently selected files. If no files are selected, the tools open a
> file selection dialog automatically.

### Step 2 — Add tag columns

1. Go to **Configuration → Options → Files views → Columns → Custom columns**
2. Click **New** and name the column set (e.g. "Music")
3. Click **Add column**, then click `+` in the field selector
4. Choose **Plugin → audioinfo** and select the desired fields:
   - **Artist** — `[Plugin(audioinfo).Artist()]`
   - **Title** — `[Plugin(audioinfo).Title()]`
   - **Album** — `[Plugin(audioinfo).Album()]`
   - **Track** — `[Plugin(audioinfo).Track()]`
   - **Year** — `[Plugin(audioinfo).Date()]`
   - **Genre** — `[Plugin(audioinfo).Genre()]`
   - **Duration** — `[Plugin(audioinfo).Duration (H:M:S)()]`
5. Save the column set and activate it by right-clicking the column header
   in the file panel → select your new column set

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

### Viewing tags as columns

1. Navigate to a folder with MP3 files
2. Right-click the column header → select your "Music" column set
3. Columns show Artist, Album, Track, etc. — click a column header to sort

---

## File Structure

```
Mp3TagTools/           (install folder, chosen during installation)
├── id3lib.py          shared tag read/write library (ID3v1 + ID3v2.3)
├── mp3tag_batch.py    batch tag editor
├── mp3tag_rename.py   rename from tags
├── run_batch.bat      DoubleCMD wrapper — Windows
├── run_batch.sh       DoubleCMD wrapper — Linux/macOS
├── run_rename.bat     DoubleCMD wrapper — Windows
└── run_rename.sh      DoubleCMD wrapper — Linux/macOS
```

```
mp3tag_dist/           (this package)
├── tools/
│   ├── id3lib.py
│   ├── mp3tag_batch.py
│   └── mp3tag_rename.py
├── install_windows.bat
├── install_linux_macos.sh
└── README.md
```

---

## Technical Notes

- **ID3v2.3 write**: tags are written with UTF-8 encoding (encoding byte `0x03`),
  which is supported by all modern players and tag editors
- **ID3v1 compatibility**: an ID3v1 tag is always appended alongside ID3v2,
  for players that only support the older format (30-character limit applies)
- **Audio data preserved**: only the tag header is rewritten; the audio stream
  is never modified
- **No external dependencies**: pure Python standard library only (`struct`,
  `os`, `tkinter`)
