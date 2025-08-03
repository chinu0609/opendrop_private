@echo off
echo Launching OpenDrop application in WSL with root permissions...
wsl.exe -d Ubuntu sudo bash -c "source /root/opendrop_venv/bin/activate && python -m opendrop"
pause
