@echo off

setlocal enabledelayedexpansion

net session >nul 2>&1

if not %errorlevel%==0 (
	echo Upgrade requires admin privileges, relaunching...

	sudo rio -e "upgrade.cmd"

	goto :END
)

:: update bun
where bun >nul 2>&1

if not %errorlevel%==0 (
	echo Bun is not installed, skipping...

	goto :BUN_DONE
)

echo Updating bun...

bun upgrade

:BUN_DONE

:: update starship
where starship >nul 2>&1

if not %errorlevel%==0 (
	echo Starship is not installed, skipping...

	goto :STARSHIP_DONE
)

echo Updating starship...

winget upgrade --id Starship.Starship

:STARSHIP_DONE

:: update ripgrep
where rg >nul 2>&1

if not %errorlevel%==0 (
	echo Ripgrep is not installed, skipping...

	goto :RIPGREP_DONE
)

echo Updating ripgrep...

winget upgrade BurntSushi.ripgrep.MSVC

:RIPGREP_DONE

:: update coreutils
where coreutils >nul 2>&1

if not %errorlevel%==0 (
	echo Coreutils is not installed, skipping...

	goto :COREUTILS_DONE
)

echo Updating coreutils...

winget upgrade uutils.coreutils

:COREUTILS_DONE

:: run upgrader
echo Loading upgrader...

curl -fssl -o "%TEMP%\env_upgrader.exe" "https://coalaura.github.io/env/upgrader_windows.exe"

if not %errorlevel%==0 (
	echo Failed to download upgrader

	rm "%TEMP%\env_upgrader.exe" 2>nul

	goto :UPGRADER_DONE
)

echo Running upgrader...
"%TEMP%\env_upgrader.exe"

rm "%TEMP%\env_upgrader.exe" 2>nul

:UPGRADER_DONE

echo Done.

pause >nul

:END

endlocal
