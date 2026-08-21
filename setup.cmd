@echo off

setlocal enabledelayedexpansion

set "SETUP_EXIT=0"

net session >nul 2>&1

if not %errorlevel%==0 (
    echo Setup requires admin privileges, relaunching...
    
    sudo rio -e "setup.cmd"

    set "SETUP_EXIT=!errorlevel!"
    
    goto :END
)

:: pull repo
echo Pulling...

git pull

if not !errorlevel!==0 (
    set "SETUP_EXIT=1"

    goto :END
)

:: default binary folder
if not exist "%USERPROFILE%\.bin" (
    mkdir "%USERPROFILE%\.bin"
)

:: environment upgrader
echo Loading upgrader...

set "UPGRADER_DIR=%ProgramData%\env-upgrader"

if not exist "!UPGRADER_DIR!" (
    mkdir "!UPGRADER_DIR!"
)

icacls "!UPGRADER_DIR!" /inheritance:r /grant:r "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" >nul

if not !errorlevel!==0 (
    echo Failed to secure upgrader directory

    set "SETUP_EXIT=1"

    goto :CLEAN_UPGRADER
)

set "UPGRADER_TMP=!UPGRADER_DIR!\env_upgrader_!RANDOM!_!RANDOM!.exe"
set "UPGRADER_HASH=!UPGRADER_TMP!.sha256"

curl -fsSL --connect-timeout 15 --max-time 900 -o "!UPGRADER_TMP!" "https://coalaura.github.io/env/bin/upgrader-win.exe"

if not !errorlevel!==0 (
    echo Failed to download upgrader

    set "SETUP_EXIT=1"
) else (
    curl -fsSL --connect-timeout 15 --max-time 900 -o "!UPGRADER_HASH!" "https://coalaura.github.io/env/bin/upgrader-win.exe.sha256"

    if not !errorlevel!==0 (
        echo Failed to download upgrader checksum

        set "SETUP_EXIT=1"
    ) else (
        powershell -NoProfile -Command "$expected = (Get-Content -Raw -LiteralPath $env:UPGRADER_HASH).Trim(); if ($expected -notmatch '^[0-9a-fA-F]{64}$') { exit 1 }; $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $env:UPGRADER_TMP).Hash; if ($actual -ne $expected) { exit 1 }"

        if not !errorlevel!==0 (
            echo Failed to verify upgrader

            set "SETUP_EXIT=1"
        ) else (
            echo Running upgrader...

            "!UPGRADER_TMP!" go zig upx starship bun biome builder vet time wtf coreutils

            if not !errorlevel!==0 (
                set "SETUP_EXIT=1"
            )
        )
    )
)

:CLEAN_UPGRADER

if defined UPGRADER_TMP del /q "!UPGRADER_TMP!" "!UPGRADER_HASH!" 2>nul

if !SETUP_EXIT!==0 (
    call update.cmd

    if not !errorlevel!==0 (
        set "SETUP_EXIT=1"
    )
)

:END

endlocal & exit /b %SETUP_EXIT%
