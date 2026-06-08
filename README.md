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
| tkinter   | —       | Bundled with Python on Windows/macOS; separate package on Linux (see below) |
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

The installer checks for Python 3 and tkinter, then copies the scripts and
creates `run_batch.sh` and `run_rename.sh` wrapper scripts in the chosen folder.

If tkinter is missing, the installer will tell you the exact command to install
it for your distribution.

### Android (Termux + proot-distro Ubuntu)

The tools run fully inside a proot-distro Ubuntu environment, which provides
a complete Linux userland including a working X display via Termux:X11.

**Step 1 — Install Termux:X11** from the Termux add-ons repository and start
the X server before proceeding.

**Step 2 — Enter Ubuntu:**

```bash
proot-distro login ubuntu
```

**Step 3 — Install dependencies:**

```bash
sudo apt update && sudo apt install -y python3 python3-tk doublecmd-gtk
```

**Step 4 — Run the installer inside proot:**

```bash
cd /path/to/mp3tag_dist
chmod +x install_linux_macos.sh
./install_linux_macos.sh
```

**Step 5 — Launch DoubleCMD:**

```bash
export DISPLAY=:0
doublecmd
```

Then configure the toolbar buttons as described in the DoubleCMD Configuration
section below, using the paths printed by the installer.

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

### Step 2 — Set up tag columns with the audioinfo plugin

The **audioinfo** plugin is a WDX (content plugin) bundled with every DoubleCMD
installation. It reads audio metadata directly from files and exposes it as
virtual columns that can be sorted, searched, and filtered just like any other
file attribute.

#### 2a — Create a column set

1. Go to **Configuration → Options → Files views → Columns**
2. Click **New** and name the column set (e.g. `Music`)
3. Add the columns you want one by one by clicking **Add column**, then
   choosing the field as described below

#### 2b — Add a plugin column

For each tag field you want to display:

1. In the column definition dialog, click the **`...`** button next to the
   *Content plugin* field (on some versions: click **`+`** in the field
   selector, then navigate to **Plugin → audioinfo**)
2. A list of available plugin fields appears — select the one you want
3. Set a **Title** (the column header text) and an optional **Width**
4. Click **OK**

#### 2c — Available audioinfo fields

| Column title    | Plugin field string                          | Typical width | Notes                          |
|-----------------|----------------------------------------------|:-------------:|--------------------------------|
| Artist          | `[Plugin(audioinfo).Artist()]`               | 140 px        |                                |
| Title           | `[Plugin(audioinfo).Title()]`                | 180 px        |                                |
| Album           | `[Plugin(audioinfo).Album()]`                | 140 px        |                                |
| Track           | `[Plugin(audioinfo).Track()]`                |  50 px        | Plain number, e.g. `3`         |
| Year            | `[Plugin(audioinfo).Date()]`                 |  50 px        | Field is named *Date* in the plugin |
| Genre           | `[Plugin(audioinfo).Genre()]`                |  90 px        |                                |
| Comment         | `[Plugin(audioinfo).Comment()]`              | 140 px        |                                |
| Duration        | `[Plugin(audioinfo).Duration (H:M:S)()]`     |  70 px        | Formatted as `H:MM:SS`         |
| Bitrate         | `[Plugin(audioinfo).Bitrate (Kbps)()]`       |  60 px        | e.g. `320`                     |
| Sample rate     | `[Plugin(audioinfo).Sample rate (Hz)()]`     |  80 px        | e.g. `44100`                   |
| Channels        | `[Plugin(audioinfo).Channels()]`             |  60 px        | e.g. `2`                       |

> **Tip:** A practical Music column set typically uses: Artist, Title, Album,
> Track, Year, Genre, Duration, and Bitrate. Sample rate and Channels are
> available but rarely needed for day-to-day browsing.

#### 2d — Activate the column set

Once you have saved the column set, activate it in the file panel:

- **Right-click** the column header bar in the file panel
- Select your column set name (e.g. `Music`) from the list

Each panel (left/right) remembers its own active column set independently,
so you can keep the Music set on one side and the default set on the other.

To switch back to the standard file columns, right-click the header again
and select the built-in `Default` set.

#### 2e — Sorting

Click any column header to sort by that field. Click again to reverse the
order. Sorting by **Track** then renaming files with the Rename from Tags
tool is a common workflow for quickly ordering an album.

#### 2f — Troubleshooting

**Columns show empty values:**
- Make sure the files are MP3s with ID3 tags (files without tags will show
  blank fields — use the Batch Tag Editor to add them)
- Check that **audioinfo** appears in
  **Configuration → Options → Plugins → Content plugins**; if it is missing,
  re-install DoubleCMD
- On Linux, if columns are empty for all files, the audioinfo plugin may need
  the `libmpg123` or `libid3tag` shared library — install it via your package
  manager (`sudo apt install libmpg123-0` on Debian/Ubuntu)

**The `Date` field shows a full ISO date instead of just the year:**
- Some taggers (e.g. MusicBrainz Picard, foobar2000) write the full date
  `2024-05-01` in the TDRC frame. The audioinfo plugin displays whatever is
  stored — use the Batch Tag Editor to normalise the Year field to a 4-digit
  value if needed

**Column set is not remembered after restart:**
- Save the column set from **Configuration → Options → Files views → Columns**
  and make sure DoubleCMD configuration is saved before closing
  (**Configuration → Save configuration**)

**Edit popup appears but is empty / not interactable (proot / Termux:X11):**
- This is a known issue with `grab_set()` on some X11 environments. This
  release already includes the fix (`lift()` + `focus_force()` instead of
  `grab_set()`); if you see this with an older version, update `mp3tag_batch.py`.

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
2. Right-click the column header → select your `Music` column set
3. Columns show Artist, Album, Track, etc. — click a column header to sort
4. To sort by track number and verify the album order before renaming,
   click the **Track** column header
5. To switch back to normal file columns, right-click the header →
   select `Default`

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
- **Atomic writes**: tag data is written to a temp file then swapped in with
  `os.replace()`, so a crash mid-write never corrupts the original file
- **proot/Termux:X11 compatibility**: the edit popup uses `lift()` +
  `focus_force()` instead of `grab_set()` for reliable focus handling on
  non-standard X11 environments
