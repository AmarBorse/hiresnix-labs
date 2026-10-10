@echo off
rem Hiresnix Labs for Windows: double-click this file.
rem The labs need Linux. This runs them in WSL (built into Windows), so Docker is not needed.
rem   start.bat           run in WSL
rem   start.bat docker    run in Docker Desktop instead (if you have it)
rem Double-clicked windows close the moment a script ends or hits an error, hiding the message. Re-run this file inside
rem "cmd /k", which keeps the window open afterwards so every message stays readable.
if defined HIRESNIX_INNER goto main
set "HIRESNIX_INNER=1"
cmd /k ""%~f0" %*"
exit /b

:main
setlocal
title Hiresnix Labs
cd /d "%~dp0"
if /i "%~1"=="docker" goto docker

where wsl.exe >nul 2>nul || goto nowsl

rem Find a WSL distribution that has bash. Docker Desktop adds its own internal distro ("docker-desktop"), which can be
rem the default and has no bash, so "WSL works" is not enough: try the default, then Ubuntu, then every other distro.
set "WSL_UTF8=1"
set "DISTRO="
wsl.exe -e bash -c "exit 0" >nul 2>nul && goto runwsl
wsl.exe -d Ubuntu -e bash -c "exit 0" >nul 2>nul && (set "DISTRO=Ubuntu" & goto runwsl)
for /f "usebackq delims=" %%d in (`wsl.exe -l -q 2^>nul`) do (
  if not defined DISTRO (
    echo %%d| findstr /i /b "docker-desktop" >nul || (
      wsl.exe -d "%%d" -e bash -c "exit 0" >nul 2>nul && set "DISTRO=%%d"
    )
  )
)
if not defined DISTRO goto nolinux

:runwsl
echo Starting Hiresnix Labs in WSL...
if defined DISTRO goto rundistro
wsl.exe --cd "%~dp0." -e bash ./start.sh
goto stopped
:rundistro
wsl.exe -d "%DISTRO%" --cd "%~dp0." -e bash ./start.sh
goto stopped

:stopped
echo.
echo Hiresnix Labs has stopped. If you see an error above, send a screenshot of this window. You can close it now.
goto :eof

:nolinux
echo.
echo  WSL is installed, but it has no Linux distribution to run the labs in.
echo  (Docker Desktop's internal "docker-desktop" one cannot run them.)
echo.
echo  1. Open "Terminal" or "PowerShell" as Administrator
echo  2. Run:   wsl --install -d Ubuntu
echo  3. Finish the Ubuntu setup (pick a username and password)
echo  4. Double-click start.bat again
echo.
where docker >nul 2>nul && echo  Or, to use Docker Desktop instead:  start.bat docker
echo.
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
goto :eof

:docker
where docker >nul 2>nul || (echo Docker is not installed. & goto :eof)
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
goto :eof

:dockerup
if "%LABS_PORT%"=="" set LABS_PORT=8080
echo Building and starting Hiresnix Labs (the first run takes a few minutes)...
docker compose up --build -d || goto :eof
start "" "http://localhost:%LABS_PORT%"
echo Hiresnix Labs is running at http://localhost:%LABS_PORT%   (close this window or press Ctrl+C to stop)
docker compose logs -f --tail 0 labs
docker compose down
