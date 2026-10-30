@echo off
rem build.bat - v20261030-0001
setlocal
cd /d "%~dp0"
echo Sea Wolf (1976) - original 8080 ROM build
if not exist roms mkdir roms
tools\zmac.exe -o src\seawolf.bin src\seawolf.asm
if errorlevel 1 exit /b 1
powershell -NoProfile -Command "$b=[IO.File]::ReadAllBytes('src\seawolf.bin'); if($b.Length -ne 4096){exit 1}; $n=@('sw0041.h','sw0042.g','sw0043.f','sw0044.e'); for($i=0;$i -lt 4;$i++){ [IO.File]::WriteAllBytes(('roms\'+$n[$i]),[byte[]]$b[($i*1024)..(($i+1)*1024-1)]) }; $sha=@('b538277d3a633dd8a3179cff202f18d322e6fe17','cc2a99b18695f61e0540c9f6bf8fe3b391dde4a0','385198434b08fe4651ad2c920d44fb49cfe0bc33','bd345dd72fed8ce15da76c381782b025f71b006f'); for($i=0;$i -lt 4;$i++){ $actual=(Get-FileHash ('roms\'+$n[$i]) -Algorithm SHA1).Hash.ToLower(); if($actual -ne $sha[$i]){Write-Error ('ROM mismatch: '+$n[$i]);exit 1} }"
if errorlevel 1 exit /b 1
powershell -NoProfile -Command "Compress-Archive -Force -Path roms\sw0041.h,roms\sw0042.g,roms\sw0043.f,roms\sw0044.e -DestinationPath roms\seawolf.zip"
if errorlevel 1 exit /b 1
echo PASS: Original ROM SHA-1 checksums verified.
