@echo off
REM build.bat - Compila i plugin Mp3Tag per DoubleCMD usando FPC direttamente

setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set OUTPUT_DIR=%SCRIPT_DIR%output
set FPC=

REM ---- Trova fpc.exe ----
for %%P in (fpc.exe) do set FPC=%%~$PATH:P

if "%FPC%"=="" (
  for %%D in (
    "C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe"
    "C:\lazarus\fpc\3.2.2\bin\i386-win32\fpc.exe"
    "C:\fpc\bin\x86_64-win64\fpc.exe"
    "C:\Program Files\FPC\bin\x86_64-win64\fpc.exe"
  ) do (
    if exist %%D set FPC=%%~D
  )
)

if "%FPC%"=="" (
  echo ERRORE: fpc.exe non trovato.
  echo Installa Free Pascal o aggiungi la sua cartella al PATH.
  pause
  exit /b 1
)

echo Usando: %FPC%
echo Output: %OUTPUT_DIR%
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

REM Flags comuni: ObjFPC, DLL Windows 64-bit, no debug info
set FLAGS=-MObjFPC -Scgi -O1 -WR -WD -FE"%OUTPUT_DIR%"

REM ---- Compila Content Plugin (WDX) ----
echo.
echo === Compilazione Content Plugin (WDX) ===
"%FPC%" %FLAGS% "%SCRIPT_DIR%content_plugin\Mp3TagWdx.pas"
if errorlevel 1 (
  echo ERRORE nella compilazione del WDX.
  pause
  exit /b 1
)
if exist "%OUTPUT_DIR%\Mp3TagWdx.dll" (
  if exist "%OUTPUT_DIR%\Mp3TagWdx.wdx" del "%OUTPUT_DIR%\Mp3TagWdx.wdx"
  rename "%OUTPUT_DIR%\Mp3TagWdx.dll" "Mp3TagWdx.wdx"
  echo OK -^> %OUTPUT_DIR%\Mp3TagWdx.wdx
) else (
  echo ERRORE: Mp3TagWdx.dll non generata.
  pause
  exit /b 1
)

REM ---- Compila DSX Plugin ----
echo.
echo === Compilazione DSX Plugin ===
"%FPC%" %FLAGS% "%SCRIPT_DIR%dsx_plugin\Mp3TagDsx.pas"
if errorlevel 1 (
  echo ERRORE nella compilazione del DSX.
  pause
  exit /b 1
)
if exist "%OUTPUT_DIR%\Mp3TagDsx.dll" (
  if exist "%OUTPUT_DIR%\Mp3TagDsx.dsx" del "%OUTPUT_DIR%\Mp3TagDsx.dsx"
  rename "%OUTPUT_DIR%\Mp3TagDsx.dll" "Mp3TagDsx.dsx"
  echo OK -^> %OUTPUT_DIR%\Mp3TagDsx.dsx
) else (
  echo ERRORE: Mp3TagDsx.dll non generata.
  pause
  exit /b 1
)

REM ---- Riepilogo ----
echo.
echo === Build completata ===
dir "%OUTPUT_DIR%\*.wdx" "%OUTPUT_DIR%\*.dsx" 2>nul
echo.
echo Installa i plugin in DoubleCMD:
echo   WDX: Configurazione -^> Plugins -^> WDX -^> Aggiungi -^> Mp3TagWdx.wdx
echo   DSX: Configurazione -^> Plugins -^> DSX -^> Aggiungi -^> Mp3TagDsx.dsx
echo.
pause
