@echo off
REM ============================================================
REM  Mp3Tag Tools for DoubleCMD - Windows Installer
REM  Requirements: Python 3, DoubleCMD
REM ============================================================
setlocal enabledelayedexpansion
echo.
echo  =============================================
echo   Mp3Tag Tools for DoubleCMD - Installer
echo  =============================================
echo.

REM ---- Check Python ----
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python 3 not found in PATH.
    echo Download Python from https://www.python.org/downloads/
    pause & exit /b 1
)
for /f "tokens=*" %%V in ('python --version 2^>^&1') do echo Python: %%V

REM ---- Choose install folder ----
echo.
echo Where do you want to install the scripts?
echo Press ENTER to use the default: %USERPROFILE%\Mp3TagTools
echo Or type a custom path:
set /p INSTALL_DIR="> "
if "%INSTALL_DIR%"=="" set INSTALL_DIR=%USERPROFILE%\Mp3TagTools

echo.
echo Install folder: %INSTALL_DIR%
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

REM ---- Copy scripts ----
echo Copying files...
copy /y "%~dp0tools\id3lib.py"          "%INSTALL_DIR%\id3lib.py"          >nul
copy /y "%~dp0tools\mp3tag_batch.py"    "%INSTALL_DIR%\mp3tag_batch.py"    >nul
copy /y "%~dp0tools\mp3tag_rename.py"   "%INSTALL_DIR%\mp3tag_rename.py"   >nul

REM ---- Create wrapper .bat files with fixed paths ----
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
echo   Installation complete!
echo  =============================================
echo.
echo  Folder: %INSTALL_DIR%
echo.
echo  Configure DoubleCMD:
echo  1. Configuration ^> Options ^> Toolbar
echo  2. Add button "External command":
echo.
echo     BATCH TAG EDITOR:
echo       Command:    cmd
echo       Parameters: /c "%INSTALL_DIR%\run_batch.bat" %%Lm
echo.
echo     RENAME FROM TAGS:
echo       Command:    cmd
echo       Parameters: /c "%INSTALL_DIR%\run_rename.bat" %%Lm
echo.
echo  3. For tag columns (Artist, Album, etc.) use the
echo     audioinfo plugin already included in DoubleCMD:
echo     Configuration ^> Options ^> Files views ^> Columns
echo     Add columns from: Plugins ^> audioinfo
echo.
pause
