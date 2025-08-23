@echo off

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
copy "clink\init.lua" "%LOCALAPPDATA%\clink\init.lua"
copy "clink\commands.lua" "%LOCALAPPDATA%\clink\commands.lua"

:: starship config
echo Copying starship config...

if not exist "%USERPROFILE%\.config" (
    mkdir "%USERPROFILE%\.config"
)

copy "starship\starship.toml" "%USERPROFILE%\.config\starship.toml"

:: biome config
echo "Copying biome config..."

copy "biome\biome.json" "%USERPROFILE%\biome.json"

:: dependencies
echo Checking dependencies...

:: install starship
where starship >nul 2>&1

if errorlevel 1 (
    echo Installing starship...
    winget install --id Starship.Starship
)

:: install coreutils
where coreutils >nul 2>&1

if errorlevel 1 (
    echo Installing coreutils...
    winget install uutils.coreutils
)

:: install ripgrep
where rg >nul 2>&1

if errorlevel 1 (
    echo Installing ripgrep...
    winget install BurntSushi.ripgrep.MSVC
)

echo Done.

if %0 == "%~0" (
    pause >nul
)
