@echo off

setlocal enabledelayedexpansion

:: rio config
echo Copying rio config...

if not exist "%LOCALAPPDATA%\rio" (
    mkdir "%LOCALAPPDATA%\rio"
)

if not exist "%LOCALAPPDATA%\rio\themes" (
    mkdir "%LOCALAPPDATA%\rio\themes"
)

copy "rio\config.toml" "%LOCALAPPDATA%\rio\config.toml"
copy "rio\themes\catppuccin-macchiato.toml" "%LOCALAPPDATA%\rio\themes\catppuccin-macchiato.toml"

:: clink config
echo Copying clink config...

if not exist "%LOCALAPPDATA%\clink" (
    mkdir "%LOCALAPPDATA%\clink"
)

copy "clink\clink_settings" "%LOCALAPPDATA%\clink\clink_settings"
copy "clink\commands.lua" "%LOCALAPPDATA%\clink\commands.lua"
copy "clink\init.lua" "%LOCALAPPDATA%\clink\init.lua"
copy "clink\json.lua" "%LOCALAPPDATA%\clink\json.lua"
copy "clink\utils.lua" "%LOCALAPPDATA%\clink\utils.lua"

:: starship config
echo Copying starship config...

if not exist "%USERPROFILE%\.config" (
    mkdir "%USERPROFILE%\.config"
)

copy "starship\starship.toml" "%USERPROFILE%\.config\starship.toml"

:: default binary folder
if not exist "%USERPROFILE%\.bin" (
    mkdir "%USERPROFILE%\.bin"
)

:: biome config
echo Copying biome config...

copy "biome\biome.json" "%USERPROFILE%\biome.json"
copy "biome\biome.json" "D:\biome.json"

:: dependencies
echo Checking dependencies...

:: install starship
where starship >nul 2>&1

if not %errorlevel%==0 (
    echo Installing starship...
    winget install --id Starship.Starship
)

:: install coreutils
where coreutils >nul 2>&1

if not %errorlevel%==0 (
    echo Installing coreutils...
    winget install uutils.coreutils
)

:: install ripgrep
where rg >nul 2>&1

if not %errorlevel%==0 (
    echo Installing ripgrep...
    winget install BurntSushi.ripgrep.MSVC
)

:: install bun
where bun >nul 2>&1

if not %errorlevel%==0 (
    echo Installing bun...
    powershell -c "irm bun.sh/install.ps1|iex"
)

:: install biome
where biome >nul 2>&1

if not %errorlevel%==0 (
    echo Installing biome...
    curl -Ls https://github.com/biomejs/biome/releases/latest/download/biome-win32-x64.exe -o "%USERPROFILE%\.bin\biome.exe"
)

endlocal

if %0 == "%~0" (
    pause >nul
)
