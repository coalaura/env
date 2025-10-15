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
echo "Copying biome config..."

copy "biome\biome.json" "%USERPROFILE%\biome.json"
copy "biome\biome.json" "D:\biome.json"

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

:: install/update biome
where biome >nul 2>&1

:: get current version
if %errorlevel%==0 (
    for /f "tokens=2" %%A in ('biome version ^| findstr /b "CLI:"') do (
        set B_CURR=%%A
    )
)

:: get latest version
echo Checking latest biome version...

for /f "usebackq tokens=2 delims=:," %%A in (`curl -s -H "Accept: application/vnd.github+json" "https://api.github.com/repos/biomejs/biome/releases/latest" ^| findstr /i "\"tag_name\""`) do (
    set B_NEW=%%~A
)

set B_NEW=%B_NEW:"=%
set B_NEW=%B_NEW: =%
set B_NEW=%B_NEW:@biomejs/biome@=%

if not defined B_NEW (
    echo Unable to retrieve latest biome version.

    goto :BIOME_DONE
)

if /i "%B_CURR%"=="%B_NEW%" (
    echo Biome %B_CURR% is up to date.

    goto :BIOME_DONE
)

if defined B_CURR (
    echo Updating biome from %B_CURR% to %B_NEW%...
) else (
    echo Installing biome %B_NEW%...
)

curl -Ls https://github.com/biomejs/biome/releases/download/@biomejs/biome@%B_NEW%/biome-win32-x64.exe -o "%USERPROFILE%\.bin\biome.exe" >nul

:BIOME_DONE

echo Done.

endlocal

if %0 == "%~0" (
    pause >nul
)
