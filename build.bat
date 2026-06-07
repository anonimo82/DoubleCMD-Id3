@echo off
REM build.bat - Compila i plugin Mp3Tag per DoubleCMD usando Lazarus

setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set OUTPUT_DIR=%SCRIPT_DIR%output
set LAZBUILD=
set OBJDUMP=C:\lazarus\fpc\3.2.2\bin\x86_64-win64\objdump.exe

REM ---- Trova lazbuild ----
for %%P in (lazbuild.exe) do set LAZBUILD=%%~$PATH:P
if "%LAZBUILD%"=="" (
  for %%D in (
    "C:\lazarus\lazbuild.exe"
    "C:\Program Files\Lazarus\lazbuild.exe"
  ) do if exist %%D set LAZBUILD=%%~D
)
if "%LAZBUILD%"=="" ( echo ERRORE: lazbuild.exe non trovato. & pause & exit /b 1 )

echo Usando: %LAZBUILD%
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

taskkill /f /im doublecmd.exe >nul 2>&1
timeout /t 1 /nobreak >nul

REM ---- Content Plugin (WDX) ----
echo.
echo === Compilazione Content Plugin (WDX) ===
"%LAZBUILD%" --build-all "%SCRIPT_DIR%content_plugin\Mp3TagWdx.lpi"
if errorlevel 1 ( echo ERRORE compilazione WDX. & pause & exit /b 1 )

if exist "%OUTPUT_DIR%\Mp3TagWdx.wdx" del /f "%OUTPUT_DIR%\Mp3TagWdx.wdx"
copy /y "%SCRIPT_DIR%content_plugin\Mp3TagWdx.dll" "%OUTPUT_DIR%\Mp3TagWdx.wdx" >nul
echo OK -^> %OUTPUT_DIR%\Mp3TagWdx.wdx

REM ---- DSX Plugin ----
echo.
echo === Compilazione DSX Plugin ===
"%LAZBUILD%" --build-all "%SCRIPT_DIR%dsx_plugin\Mp3TagDsx.lpi"
if errorlevel 1 ( echo ERRORE compilazione DSX. & pause & exit /b 1 )

if exist "%OUTPUT_DIR%\Mp3TagDsx.dsx" del /f "%OUTPUT_DIR%\Mp3TagDsx.dsx"
copy /y "%SCRIPT_DIR%dsx_plugin\Mp3TagDsx.dll" "%OUTPUT_DIR%\Mp3TagDsx.dsx" >nul
echo OK -^> %OUTPUT_DIR%\Mp3TagDsx.dsx

REM ---- Verifica ----
echo.
echo === Verifica exports WDX ===
if exist "%OBJDUMP%" (
  "%OBJDUMP%" -p "%OUTPUT_DIR%\Mp3TagWdx.wdx" | findstr /i "content"
)

echo.
echo === Build completata ===
dir "%OUTPUT_DIR%\Mp3TagWdx.wdx" "%OUTPUT_DIR%\Mp3TagDsx.dsx" 2>nul
echo.
pause
