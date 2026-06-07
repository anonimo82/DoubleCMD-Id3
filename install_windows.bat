@echo off
REM ============================================================
REM  Mp3Tag Tools per DoubleCMD - Installer Windows
REM  Requisiti: Python 3, DoubleCMD
REM ============================================================
setlocal enabledelayedexpansion
echo.
echo  =============================================
echo   Mp3Tag Tools per DoubleCMD - Installer
echo  =============================================
echo.

REM ---- Verifica Python ----
python --version >nul 2>&1
if errorlevel 1 (
    echo ERRORE: Python 3 non trovato nel PATH.
    echo Scarica Python da https://www.python.org/downloads/
    pause & exit /b 1
)
for /f "tokens=*" %%V in ('python --version 2^>^&1') do echo Python: %%V

REM ---- Scegli cartella di installazione ----
echo.
echo Dove vuoi installare gli script?
echo Premi INVIO per usare il default: %USERPROFILE%\Mp3TagTools
echo Oppure digita un percorso personalizzato:
set /p INSTALL_DIR="> "
if "%INSTALL_DIR%"=="" set INSTALL_DIR=%USERPROFILE%\Mp3TagTools

echo.
echo Cartella di installazione: %INSTALL_DIR%
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

REM ---- Copia gli script ----
echo Copio i file...
copy /y "%~dp0tools\id3lib.py"          "%INSTALL_DIR%\id3lib.py"          >nul
copy /y "%~dp0tools\mp3tag_batch.py"    "%INSTALL_DIR%\mp3tag_batch.py"    >nul
copy /y "%~dp0tools\mp3tag_rename.py"   "%INSTALL_DIR%\mp3tag_rename.py"   >nul

REM ---- Crea wrapper .bat con percorso fisso ----
echo @echo off > "%INSTALL_DIR%\run_batch.bat"
echo set TMPFILE=%%TEMP%%\mp3tag_files.txt >> "%INSTALL_DIR%\run_batch.bat"
echo type nul ^> "%%TMPFILE%%" >> "%INSTALL_DIR%\run_batch.bat"
echo for %%%%F in (%%*) do echo %%%%~F ^>^> "%%TMPFILE%%" >> "%INSTALL_DIR%\run_batch.bat"
echo pythonw "%INSTALL_DIR%\mp3tag_batch.py" --filelist "%%TMPFILE%%" >> "%INSTALL_DIR%\run_batch.bat"
echo del "%%TMPFILE%%" 2^>nul >> "%INSTALL_DIR%\run_batch.bat"

echo @echo off > "%INSTALL_DIR%\run_rename.bat"
echo set TMPFILE=%%TEMP%%\mp3tag_rename.txt >> "%INSTALL_DIR%\run_rename.bat"
echo type nul ^> "%%TMPFILE%%" >> "%INSTALL_DIR%\run_rename.bat"
echo for %%%%F in (%%*) do echo %%%%~F ^>^> "%%TMPFILE%%" >> "%INSTALL_DIR%\run_rename.bat"
echo pythonw "%INSTALL_DIR%\mp3tag_rename.py" --filelist "%%TMPFILE%%" >> "%INSTALL_DIR%\run_rename.bat"
echo del "%%TMPFILE%%" 2^>nul >> "%INSTALL_DIR%\run_rename.bat"

echo.
echo  =============================================
echo   Installazione completata!
echo  =============================================
echo.
echo  Cartella: %INSTALL_DIR%
echo.
echo  Configura DoubleCMD:
echo  1. Configuration ^> Options ^> Toolbar
echo  2. Aggiungi pulsante "External command":
echo.
echo     BATCH EDITOR:
echo       Command:    cmd
echo       Parameters: /c "%INSTALL_DIR%\run_batch.bat" %%Lm
echo.
echo     RINOMINA DAI TAG:
echo       Command:    cmd
echo       Parameters: /c "%INSTALL_DIR%\run_rename.bat" %%Lm
echo.
echo  3. Per le colonne (Artista, Album, ecc.) usa il plugin
echo     audioinfo gia incluso in DoubleCMD:
echo     Configuration ^> Options ^> Files views ^> Columns
echo     Aggiungi colonne da: Plugins ^> audioinfo
echo.
pause
