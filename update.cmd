@echo off

setlocal enabledelayedexpansion

echo Updating configuration files...

:: rio config
where rio >nul 2>&1

if %errorlevel%==0 (
    echo Copying rio config...

    if not exist "%LOCALAPPDATA%\rio\themes" (
        mkdir "%LOCALAPPDATA%\rio\themes"
    )

    copy /y "rio\config.toml" "%LOCALAPPDATA%\rio\config.toml" >nul
    copy /y "rio\themes\catppuccin-macchiato.toml" "%LOCALAPPDATA%\rio\themes\catppuccin-macchiato.toml" >nul
)

:: clink config
echo Copying clink config...

if not exist "%LOCALAPPDATA%\clink" (
    mkdir "%LOCALAPPDATA%\clink"
)

copy /y "clink\clink_settings" "%LOCALAPPDATA%\clink\clink_settings" >nul
copy /y "clink\commands.lua" "%LOCALAPPDATA%\clink\commands.lua" >nul
copy /y "clink\completions.lua" "%LOCALAPPDATA%\clink\completions.lua" >nul
copy /y "clink\init.lua" "%LOCALAPPDATA%\clink\init.lua" >nul
copy /y "clink\json.lua" "%LOCALAPPDATA%\clink\json.lua" >nul
copy /y "clink\utils.lua" "%LOCALAPPDATA%\clink\utils.lua" >nul

:: starship config
where starship >nul 2>&1

if %errorlevel%==0 (
    echo Copying starship config...

    if not exist "%USERPROFILE%\.config" (
        mkdir "%USERPROFILE%\.config"
    )

    copy /y "starship\starship.toml" "%USERPROFILE%\.config\starship.toml" >nul
)

:: git config
where git >nul 2>&1

if %errorlevel%==0 (
    echo Copying git config...

    if not exist "%USERPROFILE%\.config" (
        mkdir "%USERPROFILE%\.config"
    )

    copy /y "git\.gitconfig" "%USERPROFILE%\.config\.gitconfig_env" >nul
)

:: biome config
where biome >nul 2>&1

if %errorlevel%==0 (
    echo Copying biome config...

    copy /y "biome\biome.json" "%USERPROFILE%\biome.json" >nul
    copy /y "biome\biome.json" "D:\biome.json" >nul
)

:: vscode keybinds.json
if exist "%APPDATA%\Code\User" (
    echo Copying vscode keybinds...

    copy /y ".vscode\keybinds.json" "%APPDATA%\Code\User\keybindings.json" >nul
)

echo Done.

echo %CMDCMDLINE% | findstr /i /c:" /c" >nul

if %errorlevel% equ 0 (
    pause >nul
)

endlocal
