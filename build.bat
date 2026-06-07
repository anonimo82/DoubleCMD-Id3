@echo off
REM build.bat – Compila entrambi i plugin Mp3Tag per DoubleCMD (Windows)

setlocal enabledelayedexpansion

set OUTPUT_DIR=%~dp0output
set LAZBUILD=

REM ---- Trova lazbuild ----
for %%P in (lazbuild.exe) do set LAZBUILD=%%~$PATH:P

if "%LAZBUILD%"=="" (
  for %%D in (
    "C:\lazarus\lazbuild.exe"
    "C:\Program Files\Lazarus\lazbuild.exe"
    "C:\Program Files (x86)\Lazarus\lazbuild.exe"
    "%LOCALAPPDATA%\Lazarus\lazbuild.exe"
  ) do (
    if exist %%D set LAZBUILD=%%~D
  )
)

if "%LAZBUILD%"=="" (
  echo ERRORE: lazbuild.exe non trovato.
  pause
  exit /b 1
)

echo Usando: %LAZBUILD%
echo Output: %OUTPUT_DIR%
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

REM ---- Compila Content Plugin (WDX) ----
echo.
echo === Compilazione Content Plugin (WDX) ===
"%LAZBUILD%" --build-all content_plugin\Mp3TagWdx.lpi
if errorlevel 1 (
  echo ERRORE nella compilazione del WDX.
  pause
  exit /b 1
)
REM Il .lpi scrive direttamente in output\ come Mp3TagWdx.dll
rename "%OUTPUT_DIR%\Mp3TagWdx.dll" "Mp3TagWdx.wdx" 2>nul
echo OK -^> %OUTPUT_DIR%\Mp3TagWdx.wdx

REM ---- Compila DSX Plugin ----
echo.
echo === Compilazione DSX Plugin ===
"%LAZBUILD%" --build-all dsx_plugin\Mp3TagDsx.lpi
if errorlevel 1 (
  echo ERRORE nella compilazione del DSX.
  pause
  exit /b 1
)
rename "%OUTPUT_DIR%\Mp3TagDsx.dll" "Mp3TagDsx.dsx" 2>nul
echo OK -^> %OUTPUT_DIR%\Mp3TagDsx.dsx

REM ---- Riepilogo ----
echo.
echo === Build completata ===
dir "%OUTPUT_DIR%"
echo.
echo Installa i plugin in DoubleCMD:
echo   WDX: Configurazione -^> Plugins -^> WDX -^> Aggiungi -^> Mp3TagWdx.wdx
echo   DSX: Configurazione -^> Plugins -^> DSX -^> Aggiungi -^> Mp3TagDsx.dsx
echo.
pause
