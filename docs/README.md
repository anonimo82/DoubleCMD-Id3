# Mp3Tag Plugin per DoubleCMD

Plugin per DoubleCMD che replica le funzionalità principali di **Mp3Tag**:
lettura/scrittura tag ID3, rinomina file dai tag, editor batch.

---

## Struttura del progetto

```
mp3tag_plugin/
├── shared/
│   └── ID3Tags.pas          ← Logica comune (lettura/scrittura tag, pattern rename)
├── content_plugin/
│   ├── Mp3TagWdx.pas        ← Content Plugin (.wdx): tag come colonne
│   └── Mp3TagWdx.lpi        ← Progetto Lazarus
├── dsx_plugin/
│   ├── Mp3TagDsx.pas        ← DSX Plugin: voci menu contestuale
│   └── Mp3TagDsx.lpi        ← Progetto Lazarus
└── docs/
    └── README.md            ← Questo file
```

---

## Requisiti

- **Lazarus** 2.2+ con Free Pascal 3.2+
- **DoubleCMD** 0.9+ (Linux, Windows, macOS)
- Nessuna dipendenza esterna (lettura ID3v1/v2 implementata da zero)

> **Nota:** Per ID3v2 completo (scrittura, UTF-16, copertine) si consiglia di
> integrare **TagLib** tramite binding Pascal (taglib-pascal).
> La versione corrente scrive ID3v1 e legge ID3v2 in modalità read-only avanzata.

---

## Compilazione

### Linux / macOS

```bash
# Content Plugin
cd content_plugin
lazbuild Mp3TagWdx.lpi
# → genera Mp3TagWdx.wdx (rinomina l'output: .so → .wdx)
mv Mp3TagWdx.so Mp3TagWdx.wdx

# DSX Plugin
cd ../dsx_plugin
lazbuild Mp3TagDsx.lpi
mv Mp3TagDsx.so Mp3TagDsx.dsx
```

### Windows

```batch
cd content_plugin
lazbuild Mp3TagWdx.lpi
ren Mp3TagWdx.dll Mp3TagWdx.wdx

cd ..\dsx_plugin
lazbuild Mp3TagDsx.lpi
ren Mp3TagDsx.dll Mp3TagDsx.dsx
```

---

## Installazione in DoubleCMD

### Content Plugin (.wdx)

1. Apri DoubleCMD → **Configurazione → Opzioni** (F9)
2. Vai su **Plugins → WDX Plugins**
3. Clicca **Aggiungi** e seleziona `Mp3TagWdx.wdx`
4. Chiudi le opzioni
5. Nel pannello file, clicca con tasto destro sull'intestazione delle colonne
   → **Configura colonne** → aggiungi colonne da "Mp3TagWdx":
   - Titolo, Artista, Album, Anno, Traccia, Genere, Commento, Versione Tag

### DSX Plugin

1. Vai su **Configurazione → Opzioni → Plugins → DSX Plugins**
2. Clicca **Aggiungi** e seleziona `Mp3TagDsx.dsx`
3. Chiudi le opzioni
4. Seleziona uno o più file MP3 nel pannello, tasto destro del mouse
5. Troverai il sottomenu **"MP3Tag: ..."** con le voci disponibili

---

## Funzionalità

### Content Plugin (WDX) – Colonne nel pannello

| Campo        | Tipo    | Descrizione                          |
|-------------|---------|--------------------------------------|
| Titolo      | stringa | Tag TIT2 (ID3v2) o Title (ID3v1)    |
| Artista     | stringa | Tag TPE1 / Artist                    |
| Album       | stringa | Tag TALB / Album                     |
| Anno        | stringa | Tag TDRC/TYER / Year                 |
| Traccia     | intero  | Tag TRCK / Track (ordinabile!)       |
| Genere      | stringa | Nome genere (192 generi ID3)         |
| Commento    | stringa | Tag COMM / Comment                   |
| Versione Tag| stringa | ID3v1 / ID3v2 / Entrambi / Nessuno  |

### DSX Plugin – Menu contestuale

| Voce                         | Descrizione                                           |
|-----------------------------|-------------------------------------------------------|
| **Mostra tag**              | Finestra informazioni tag del file selezionato        |
| **Rinomina dai tag…**       | Rinomina con pattern personalizzabile (anteprima live)|
| **Modifica tag…**           | Editor grafico del singolo file                       |
| **Batch tag editor…**       | Griglia editabile per modificare più file insieme     |
| **Pulizia tag**             | Trim automatico degli spazi nei tag                  |

---

## Pattern di rinomina

Nella finestra "Rinomina dai tag" puoi usare queste variabili:

| Variabile   | Contenuto                          |
|------------|-------------------------------------|
| `%title%`  | Titolo del brano                    |
| `%artist%` | Artista                             |
| `%album%`  | Album                               |
| `%year%`   | Anno                                |
| `%track%`  | Numero traccia (zero-padded a 2 cifre) |
| `%genre%`  | Genere                              |
| `%ext%`    | Estensione originale (es. `.mp3`)   |

**Esempi:**
```
%track% - %artist% - %title%
→ 03 - Pink Floyd - Money.mp3

%artist%\%album%\%track% - %title%
→ Pink Floyd\Dark Side of the Moon\03 - Money.mp3
```

I caratteri non validi per il filesystem (`/ \ : * ? " < > |`) vengono
automaticamente sostituiti con `_`.

---

## Architettura del codice

```
ID3Tags.pas (shared)
│
├── ReadTagsFromFile()         Legge ID3v2 poi fallback ID3v1
├── WriteTagsToFile()          Scrive ID3v1 (semplice, universale)
├── BuildFilenameFromPattern() Sostituisce variabili nel pattern
├── GenreIndexToName()         Converte indice → nome genere
└── GenreNameToIndex()         Converte nome → indice genere

Mp3TagWdx.pas (content plugin)
├── GetSupportedField()        Registra i campi disponibili
└── GetValue()                 Restituisce il valore del campo per un file

Mp3TagDsx.pas (dsx plugin)
├── DsxGetMenuItems()          Registra le voci di menu
├── DsxExecuteFile()           Esegue l'azione selezionata
├── TTagEditorForm             Form editor singolo file
├── TBatchEditorForm           Form batch editor (griglia)
└── TRenameForm                Form rinomina con anteprima
```

---

## Roadmap / miglioramenti futuri

- [ ] Scrittura ID3v2 nativa (UTF-8, frame COMM, APIC per copertine)
- [ ] Integrazione TagLib via binding Pascal
- [ ] Ricerca automatica copertine (MusicBrainz / Last.fm API)
- [ ] Import/export tag da/verso CSV
- [ ] Supporto file FLAC, OGG, M4A (tag Vorbis / APE / iTunes)
- [ ] Undo/Redo nel batch editor
- [ ] Filtri avanzati nel batch editor (es. "solo file senza artista")

---

## Licenza

MIT License – libero uso, modifica e distribuzione.
