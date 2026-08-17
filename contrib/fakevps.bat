@echo off
REM Windows launcher: runs FakeVPS inside WSL2 (not a Linux VM).
wsl -e bash -lc "cd \"$(wslpath '%~dp0..')\" && ./fakevps %*"
