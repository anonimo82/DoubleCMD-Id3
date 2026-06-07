# Mp3Tag Tools per DoubleCMD

Strumenti per gestire i tag ID3 dei file MP3 direttamente da DoubleCMD,
con funzionalità simili a Mp3Tag:

- **Batch Tag Editor** — modifica i tag di più file MP3 in una griglia,
  con possibilità di applicare un valore a tutti i file in una volta
- **Rinomina dai tag** — rinomina i file usando i tag ID3 con pattern
  personalizzabile (es. `%track% - %artist% - %title%`) e anteprima live

---

## Requisiti

- **DoubleCMD** 0.9+ (Windows, Linux, macOS)
- **Python 3.6+** installato e nel PATH
- **audioinfo** plugin WDX (già incluso in DoubleCMD) per visualizzare
  i tag come colonne nel pannello file

---

## Installazione

### Windows

```
install_windows.bat
```

Esegui come amministratore se necessario. Lo script chiede dove installare
gli script e mostra le istruzioni per configurare DoubleCMD.

### Linux / macOS

```bash
chmod +x install_linux_macos.sh
./install_linux_macos.sh
```

---

## Configurazione DoubleCMD

### Pulsanti nella barra degli strumenti

Dopo l'installazione, aggiungi i pulsanti in
**Configuration → Options → Toolbar → Insert new button**:

**Batch Tag Editor:**
- Tipo: External command
- Command: `cmd` (Windows) oppure il percorso di `run_batch.sh` (Linux/macOS)
- Parameters: `/c "INSTALL_DIR\run_batch.bat" %Lm` (Windows)
  oppure `%Lm` (Linux/macOS)

**Rinomina dai tag:**
- Tipo: External command
- Command: `cmd` (Windows) oppure il percorso di `run_rename.sh` (Linux/macOS)
- Parameters: `/c "INSTALL_DIR\run_rename.bat" %Lm` (Windows)
  oppure `%Lm` (Linux/macOS)

### Colonne con tag ID3 (Artista, Album, ecc.)

Usa il plugin **audioinfo** già incluso in DoubleCMD:

1. **Configuration → Options → Files views → Columns → Custom columns**
2. Crea un nuovo set di colonne (es. "Music")
3. Aggiungi colonne cliccando `+` → **Plugin → audioinfo**:
   - Artist, Title, Album, Track, Genre, Comment, Year

---

## Uso

### Batch Tag Editor

1. Seleziona uno o più file MP3 nel pannello di DoubleCMD
2. Clicca il pulsante nella barra degli strumenti
3. Fai doppio clic su una cella per modificarla
4. Spunta **"Applica a TUTTI i file"** per modificare un campo su tutti i file
5. Clicca **Salva tutto**

### Rinomina dai tag

1. Seleziona i file MP3 da rinominare
2. Clicca il pulsante nella barra degli strumenti
3. Imposta il pattern di rinomina (es. `%track% - %artist% - %title%`)
4. Verifica l'anteprima
5. Clicca **Rinomina**

**Variabili pattern:**
`%title%` `%artist%` `%album%` `%year%` `%track%` `%genre%` `%ext%`

---

## Struttura file

```
Mp3TagTools/
├── tools/
│   ├── id3lib.py           ← libreria condivisa lettura/scrittura tag
│   ├── mp3tag_batch.py     ← batch editor
│   └── mp3tag_rename.py    ← rinomina dai tag
├── install_windows.bat     ← installer Windows
├── install_linux_macos.sh  ← installer Linux/macOS
└── README.md               ← questo file
```
