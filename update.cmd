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
	del /f /q "%OPENCODE_DIR%\tui.json" >nul 2>&1
	del /f /q "%OPENCODE_DIR%\dcp.json" >nul 2>&1

	:: not yet v2
	del /f /q "%OPENCODE_DIR%\cli.json" >nul 2>&1
	del /f /q "%OPENCODE_DIR%\cli.jsonc" >nul 2>&1

	:: cleanly copy commands
	robocopy "slop\commands" "%OPENCODE_DIR%\commands" /MIR >nul

	:: cleanly copy plugins
	robocopy "slop\plugins" "%OPENCODE_DIR%\plugins" /MIR >nul

	:: cleanly copy skills
	robocopy "slop\skills" "%OPENCODE_DIR%\skills" /MIR >nul

	:: copy configs
	copy /y "slop\opencode.jsonc" "%OPENCODE_DIR%\opencode.jsonc" >nul
	copy /y "slop\tui.jsonc" "%OPENCODE_DIR%\tui.jsonc" >nul
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

:: firefox config
setlocal disabledelayedexpansion

set "FIREFOX_DIR=%APPDATA%\Mozilla\Firefox"

if exist "%FIREFOX_DIR%\profiles.ini" (
	echo Copying firefox config...

	set "FIREFOX_RELATIVE=1"

	for /f "usebackq tokens=1,* delims==" %%A in ("%FIREFOX_DIR%\profiles.ini") do (
		if "%%A"=="IsRelative" (
			set "FIREFOX_RELATIVE=%%B"
		)

		if "%%A"=="Path" (
			set "FIREFOX_PROFILE=%%B"

			setlocal enabledelayedexpansion

			if "!FIREFOX_RELATIVE!"=="1" (
				set "FIREFOX_PROFILE=!FIREFOX_DIR!\!FIREFOX_PROFILE!"
			)

			if exist "!FIREFOX_PROFILE!\" (
				if not exist "!FIREFOX_PROFILE!\chrome\" mkdir (
					"!FIREFOX_PROFILE!\chrome"
				)

				copy /y "firefox\userChrome.css" "!FIREFOX_PROFILE!\chrome\userChrome.css" >nul
				copy /y "firefox\user.js" "!FIREFOX_PROFILE!\user.js" >nul
			)

			endlocal
		)
	)
)

endlocal

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
