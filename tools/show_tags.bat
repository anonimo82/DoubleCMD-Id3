@echo off
REM Mostra i tag ID3 del file passato come argomento
REM Uso: show_tags.bat "percorso\file.mp3"
setlocal
set FILE=%~1
if "%FILE%"=="" (echo Nessun file specificato. & pause & exit /b 1)
if not exist "%FILE%" (echo File non trovato: %FILE% & pause & exit /b 1)

REM Usa PowerShell per leggere il tag ID3v1 (128 byte dalla fine)
powershell -NoProfile -Command ^
  "$f='%FILE%'; $s=[System.IO.File]::OpenRead($f); $s.Seek(-128,2)|Out-Null; $b=New-Object byte[] 128; $s.Read($b,0,128)|Out-Null; $s.Close(); if([System.Text.Encoding]::ASCII.GetString($b,0,3) -eq 'TAG'){$enc=[System.Text.Encoding]::Latin1; Write-Host 'Titolo: ' $enc.GetString($b,3,30).TrimEnd([char]0).Trim(); Write-Host 'Artista:' $enc.GetString($b,33,30).TrimEnd([char]0).Trim(); Write-Host 'Album:  ' $enc.GetString($b,63,30).TrimEnd([char]0).Trim(); Write-Host 'Anno:   ' $enc.GetString($b,93,4).TrimEnd([char]0).Trim(); Write-Host 'Traccia:' $b[126]; Write-Host 'Genere: ' $b[127]}else{Write-Host 'Nessun tag ID3v1 trovato.'}"
pause
