@echo off
cd /d "%~dp0"
set "APPDATA=%~dp0.runtime"
start "Pixel Ninja" ".engine\Godot_v4.7.2-stable_win64.exe" --path "%~dp0."
