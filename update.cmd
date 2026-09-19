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

xcopy /y /q "clink\*" "%LOCALAPPDATA%\clink\" >nul

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

:: opencode config
set "OPENCODE_DIR=%USERPROFILE%\.config\opencode"

if exist "%OPENCODE_DIR%\" (
	echo Copying opencode config...


	:: non jsonc/json
	del /f /q "%OPENCODE_DIR%\opencode.json" >nul 2>&1
	del /f /q "%OPENCODE_DIR%\cli.jsonc" >nul 2>&1
	del /f /q "%OPENCODE_DIR%\dcp.json" >nul 2>&1

	:: old v1
	del /f /q "%OPENCODE_DIR%\tui.json" >nul 2>&1
	del /f /q "%OPENCODE_DIR%\tui.jsonc" >nul 2>&1

	:: cleanly copy commands
	robocopy "slop\commands" "%OPENCODE_DIR%\commands" /MIR >nul

	:: cleanly copy plugins
	robocopy "slop\plugins" "%OPENCODE_DIR%\plugins" /MIR >nul

	:: copy configs
	copy /y "slop\opencode.jsonc" "%OPENCODE_DIR%\opencode.jsonc" >nul
	copy /y "slop\cli.json" "%OPENCODE_DIR%\cli.json" >nul
	copy /y "slop\dcp.jsonc" "%OPENCODE_DIR%\dcp.jsonc" >nul

	copy /y "slop\AGENTS.md" "%OPENCODE_DIR%\AGENTS.md" >nul
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

:: autohotkey
if exist "%USERPROFILE%\Desktop\hotkeys.ahk" (
	echo Copying autohotkeys...

	copy /y "ahk\hotkeys.ahk" "%USERPROFILE%\Desktop\hotkeys.ahk" >nul
)

echo Done.

echo %CMDCMDLINE% | findstr /i /c:" /c" >nul

if %errorlevel% equ 0 (
    pause >nul
)

endlocal
