@echo off
REM build.bat – Compila entrambi i plugin Mp3Tag per DoubleCMD (Windows)
REM Uso: build.bat [debug]

setlocal enabledelayedexpansion

set OUTPUT_DIR=%~dp0output
set LAZBUILD=

REM ---- Trova lazbuild ----
for %%P in (lazbuild.exe) do set LAZBUILD=%%~$PATH:P

if "%LAZBUILD%"=="" (
  REM Posizioni comuni di Lazarus su Windows
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
  echo Installa Lazarus o aggiungi la sua cartella al PATH.
  pause
  exit /b 1
)

echo Usando: %LAZBUILD%
echo Output: %OUTPUT_DIR%
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

REM ---- Modalità debug o release ----
if /i "%1"=="debug" (
  set BUILD_MODE=--build-mode=Debug
  echo Modalita: DEBUG
) else (
  set BUILD_MODE=--build-mode=Release
  echo Modalita: RELEASE
)

REM ---- Compila Content Plugin (WDX) ----
echo.
echo === Compilazione Content Plugin (WDX) ===
"%LAZBUILD%" %BUILD_MODE% content_plugin\Mp3TagWdx.lpi
if errorlevel 1 (
  echo ERRORE nella compilazione del WDX.
  pause
  exit /b 1
)

REM Cerca la DLL generata nelle sottocartelle di lib
set WDX_SRC=
for /r "content_plugin" %%F in (Mp3TagWdx.dll) do set WDX_SRC=%%F

if "%WDX_SRC%"=="" (
  echo ERRORE: Mp3TagWdx.dll non trovata dopo la compilazione.
  pause
  exit /b 1
)
copy /y "%WDX_SRC%" "%OUTPUT_DIR%\Mp3TagWdx.wdx" >nul
echo OK -^> %OUTPUT_DIR%\Mp3TagWdx.wdx

REM ---- Compila DSX Plugin ----
echo.
echo === Compilazione DSX Plugin ===
"%LAZBUILD%" %BUILD_MODE% dsx_plugin\Mp3TagDsx.lpi
if errorlevel 1 (
  echo ERRORE nella compilazione del DSX.
  pause
  exit /b 1
)

set DSX_SRC=
for /r "dsx_plugin" %%F in (Mp3TagDsx.dll) do set DSX_SRC=%%F

if "%DSX_SRC%"=="" (
  echo ERRORE: Mp3TagDsx.dll non trovata dopo la compilazione.
  pause
  exit /b 1
)
copy /y "%DSX_SRC%" "%OUTPUT_DIR%\Mp3TagDsx.dsx" >nul
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
