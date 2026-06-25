@echo off

setlocal enabledelayedexpansion

net session >nul 2>&1

if not %errorlevel%==0 (
    echo Setup requires admin privileges, relaunching...
    
    sudo rio -e "setup.cmd"
    
    goto :END
)

:: pull repo
echo Pulling...

git pull

:: default binary folder
if not exist "%USERPROFILE%\.bin" (
    mkdir "%USERPROFILE%\.bin"
)

:: environment upgrader
echo Loading upgrader...

curl -fssl -o "%TEMP%\env_upgrader.exe" "https://coalaura.github.io/env/bin/upgrader-win.exe"

if not %errorlevel%==0 (
    echo Failed to download upgrader
    
	del /q "%TEMP%\env_upgrader.exe" 2>nul
) else (
    echo Running upgrader...
    
	"%TEMP%\env_upgrader.exe" go zig upx starship bun biome vet time wtf coreutils

    del /q "%TEMP%\env_upgrader.exe" 2>nul
)

call update.cmd

:END

endlocal