@echo off
TITLE Mewar Guardian - Production Backend
echo =======================================================
echo  MEWAR GUARDIAN - BACKEND STARTUP
echo =======================================================
echo.
echo Installing dependencies if missing...
pip install waitress

:loop
echo.
echo Starting Production Server...
python run_server.py
echo.
echo Server process crashed or stopped!
echo Restarting in 5 seconds...
timeout /t 5
goto loop
