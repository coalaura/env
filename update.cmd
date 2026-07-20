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

xcopy /y /q "clink\*" "%LOCALAPPDATA%\clink\"

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

:: go staticcheck config
where go >nul 2>&1

if %errorlevel%==0 (
    echo Copying staticcheck config...

    copy /y "go\staticcheck.conf" "%USERPROFILE%\staticcheck.conf" >nul
)

:: opencode config
if exist "%USERPROFILE%\.config\opencode\" (
	echo Copying opencode config...

	if exist "%USERPROFILE%\.config\opencode\opencode.json" (
		del "%USERPROFILE%\.config\opencode\opencode.json"
	)

	copy /y "slop\opencode.jsonc" "%USERPROFILE%\.config\opencode\opencode.jsonc"
)

:: vscode keybinds and snippets
if exist "%APPDATA%\Code\User" (
    echo Copying vscode config...

    copy /y "code\keybinds.json" "%APPDATA%\Code\User\keybindings.json" >nul

    if not exist "%APPDATA%\Code\User\snippets" (
        mkdir "%APPDATA%\Code\User\snippets"
    )

    copy /y "code\default.code-snippets" "%APPDATA%\Code\User\snippets\default.code-snippets" >nul
)

echo Done.

echo %CMDCMDLINE% | findstr /i /c:" /c" >nul

if %errorlevel% equ 0 (
    pause >nul
)

endlocal
