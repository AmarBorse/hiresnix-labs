@echo off
rem Hiresnix Labs for Windows: double-click this file.
rem The labs need Linux. This runs them in WSL (built into Windows), so Docker is not needed.
rem   start.bat           run in WSL
rem   start.bat docker    run in Docker Desktop instead (if you have it)
setlocal
title Hiresnix Labs
cd /d "%~dp0"
if /i "%~1"=="docker" goto docker

where wsl.exe >nul 2>nul || goto nowsl
wsl.exe -e true >nul 2>nul || goto nowsl
echo Starting Hiresnix Labs in WSL...
wsl.exe --cd "%~dp0." -e bash ./start.sh
if errorlevel 1 pause
goto :eof

:nowsl
echo.
echo  WSL (Linux for Windows) is not set up yet. It is free and built into Windows.
echo.
echo  1. Open "Terminal" or "PowerShell" as Administrator
echo  2. Run:   wsl --install
echo  3. Restart the computer, finish the Ubuntu setup (pick a username and password)
echo  4. Double-click start.bat again
echo.
where docker >nul 2>nul && echo  Already have Docker Desktop? Run:  start.bat docker
echo.
pause
goto :eof

:docker
where docker >nul 2>nul || (echo Docker is not installed. & pause & goto :eof)
docker info >nul 2>nul && goto dockerup
echo Starting Docker Desktop...
start "" "%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
set /a tries=0
:waitdocker
timeout /t 2 /nobreak >nul
docker info >nul 2>nul && goto dockerup
set /a tries+=1
if %tries% lss 90 goto waitdocker
echo Docker did not start. Open Docker Desktop, wait until it is running, then try again.
pause
goto :eof

:dockerup
if "%LABS_PORT%"=="" set LABS_PORT=8080
echo Building and starting Hiresnix Labs (the first run takes a few minutes)...
docker compose up --build -d || (pause & goto :eof)
start "" "http://localhost:%LABS_PORT%"
echo Hiresnix Labs is running at http://localhost:%LABS_PORT%   (close this window or press Ctrl+C to stop)
docker compose logs -f --tail 0 labs
docker compose down
