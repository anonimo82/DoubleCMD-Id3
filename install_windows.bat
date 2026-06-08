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

REM ---- Generate wrapper .bat files ----
python "%~dp0make_wrappers.py" "%INSTALL_DIR%"

if errorlevel 1 (
    echo ERROR: Failed to write wrapper scripts.
    pause & exit /b 1
)

REM ---- Auto-configure DoubleCMD toolbar ----
echo.
echo Configuring DoubleCMD toolbar...
echo IMPORTANT: Make sure DoubleCMD is closed before continuing.
pause
python "%~dp0android\configure_doublecmd.py" "%INSTALL_DIR%"

if errorlevel 1 (
    echo.
    echo WARNING: Could not auto-configure DoubleCMD.
    echo Add toolbar buttons manually as described below.
)

echo.
echo  =============================================
echo   Installation complete!
echo  =============================================
echo.
echo  Folder: %INSTALL_DIR%
echo.
echo  If toolbar buttons were not added automatically:
echo  1. Configuration ^> Options ^> Toolbar
echo  2. Add button "External command":
echo.
echo     BATCH TAG EDITOR:
echo       Command:    %INSTALL_DIR%\run_batch.bat
echo       Parameters: %%p
echo.
echo     RENAME FROM TAGS:
echo       Command:    %INSTALL_DIR%\run_rename.bat
echo       Parameters: %%p
echo.
echo  NOTE: Use the .bat file as Command directly (not cmd /c).
echo.
echo  3. For tag columns use the audioinfo plugin:
echo     Configuration ^> Options ^> Files views ^> Columns
echo     Add columns from: Plugins ^> audioinfo
echo.
pause
