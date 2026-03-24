@echo off

setlocal enabledelayedexpansion

net session >nul 2>&1

if not %errorlevel%==0 (
    echo Setup requires admin privileges, relaunching...
    
    sudo rio -e "setup.cmd"
    
    goto :END
)

echo Setting up and upgrading dependencies...

:: default binary folder
if not exist "%USERPROFILE%\.bin" (
    mkdir "%USERPROFILE%\.bin"
)

:: starship
echo Installing/Upgrading starship...

where starship >nul 2>&1

if %errorlevel%==0 (
    winget upgrade --id Starship.Starship
) else (
    winget install --id Starship.Starship
)

:: coreutils
echo Installing/Upgrading coreutils...

where coreutils >nul 2>&1

if %errorlevel%==0 (
    winget upgrade uutils.coreutils
) else (
    winget install uutils.coreutils
)

:: bun
echo Installing/Upgrading bun...

where bun >nul 2>&1

if %errorlevel%==0 (
    bun upgrade
) else (
    powershell -c "irm bun.sh/install.ps1|iex"
)

:: biome
echo Installing/Upgrading biome...

curl -Ls https://github.com/biomejs/biome/releases/latest/download/biome-win32-x64.exe -o "%USERPROFILE%\.bin\biome.exe"

:: zig
echo Installing/Upgrading zig...

where zig >nul 2>&1

if %errorlevel%==0 (
    winget upgrade --id zig.zig
) else (
    winget install --id zig.zig
)

:: upx
echo Installing/Upgrading upx...

where upx >nul 2>&1

if %errorlevel%==0 (
    winget upgrade --id UPX.UPX
) else (
    winget install --id UPX.UPX
)

:: time
echo Installing/Upgrading time...

curl -L "https://github.com/coalaura/time/releases/download/v0.1.0/time_v0.1.0_windows_amd64.exe" -o "%USERPROFILE%\.bin\time.exe"

:: environment upgrader
echo Loading env upgrader...

curl -fssl -o "%TEMP%\env_upgrader.exe" "https://coalaura.github.io/env/upgrader_windows.exe"

if not %errorlevel%==0 (
    echo Failed to download upgrader
    
	del /q "%TEMP%\env_upgrader.exe" 2>nul
) else (
    echo Running upgrader...
    
	"%TEMP%\env_upgrader.exe"

    del /q "%TEMP%\env_upgrader.exe" 2>nul
)

echo Done.

pause >nul

:END

endlocal