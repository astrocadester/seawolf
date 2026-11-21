@echo off
rem Sea Wolf original Intel 8080 ROM build — bundled zmac v1.3.
setlocal
cd /d "%~dp0"
if not exist build mkdir build
if not exist roms mkdir roms
if exist build\seawolf.bin del /q build\seawolf.bin
if exist build\seawolf.lst del /q build\seawolf.lst
if exist roms\seawolf.zip del /q roms\seawolf.zip
tools\zmac.exe -c -o build\seawolf.bin -x build\seawolf.lst src\seawolf.asm
if errorlevel 1 exit /b 1
powershell -NoProfile -Command "$ErrorActionPreference='Stop'; $b=[IO.File]::ReadAllBytes('build\seawolf.bin'); if($b.Length -ne 4096){throw 'Expected 4096 bytes'}; $n=@('sw0041.h','sw0042.g','sw0043.f','sw0044.e'); $sha=@('b538277d3a633dd8a3179cff202f18d322e6fe17','cc2a99b18695f61e0540c9f6bf8fe3b391dde4a0','385198434b08fe4651ad2c920d44fb49cfe0bc33','bd345dd72fed8ce15da76c381782b025f71b006f'); for($i=0;$i -lt 4;$i++){ $out='build\'+$n[$i]; [IO.File]::WriteAllBytes($out,[byte[]]$b[($i*1024)..(($i+1)*1024-1)]); $actual=(Get-FileHash $out -Algorithm SHA1).Hash.ToLower(); if($actual -ne $sha[$i]){throw ($n[$i]+' SHA-1: expected '+$sha[$i]+', got '+$actual)}; Write-Host ('PASS '+$n[$i]+' '+$actual) }"
if errorlevel 1 exit /b 1
powershell -NoProfile -Command "Compress-Archive -Force -Path build\sw0041.h,build\sw0042.g,build\sw0043.f,build\sw0044.e -DestinationPath roms\seawolf.zip"
if errorlevel 1 exit /b 1
echo PASS: ROM image and SHA-1 verified; roms\seawolf.zip
