@echo off
echo Starting Rakshak AI Backend Server...
start "Rakshak AI Backend" python app.py
timeout /t 3 /nobreak > nul

echo Starting Ngrok Tunnel...
start "Ngrok Tunnel" python run_ngrok.py

echo.
echo Both servers are now running in separate windows.
echo DO NOT CLOSE those windows if you want the app to keep working!
pause
