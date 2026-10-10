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

rem Find a WSL distribution that has bash. Docker Desktop adds its own internal distro ("docker-desktop"), which is often
rem the default and has no bash, so "WSL works" is not enough. Known Linux distros are tried by name first, then the default.
rem Exit codes are compared with "equ 0" on purpose: WSL errors can be negative, which "&&" and "if errorlevel" misread.
rem To force one:  set HIRESNIX_DISTRO=<name from "wsl -l -v">  then run start.bat
set "DISTRO="
set "USE_DEFAULT="
if defined HIRESNIX_DISTRO goto forced
for %%n in (Ubuntu Ubuntu-24.04 Ubuntu-22.04 Ubuntu-20.04 Debian) do if not defined DISTRO call :trydistro %%n
if defined DISTRO goto runwsl
call :trydefault
if defined USE_DEFAULT goto runwsl
goto nolinux

:forced
set "DISTRO=%HIRESNIX_DISTRO%"
goto runwsl

:trydistro
wsl.exe -d %1 -e bash -c "exit 0" >nul 2>nul
if %errorlevel% equ 0 set "DISTRO=%~1"
exit /b

:trydefault
wsl.exe -e bash -c "exit 0" >nul 2>nul
if %errorlevel% equ 0 set "USE_DEFAULT=1"
exit /b

:runwsl
if defined DISTRO goto rundistro
echo Starting Hiresnix Labs in WSL (default distribution)...
wsl.exe --cd "%~dp0." -e bash ./start.sh
goto stopped
:rundistro
echo Starting Hiresnix Labs in WSL (%DISTRO%)...
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
echo  Already have Ubuntu? Make it the default:  wsl --set-default Ubuntu
echo  Your WSL distributions:
wsl.exe -l -v
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
echo  Already have Ubuntu? Make it the default:  wsl --set-default Ubuntu
echo  Your WSL distributions:
wsl.exe -l -v
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
