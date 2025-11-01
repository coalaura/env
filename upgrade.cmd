@echo off

setlocal enabledelayedexpansion

:: update bun
where bun >nul 2>&1

if not %errorlevel%==0 (
	echo Bun is not installed, skipping...

	goto :BUN_DONE
)

echo Updating bun...

bun upgrade

:BUN_DONE

:: update biome
where biome >nul 2>&1

if not %errorlevel%==0 (
	echo Biome is not installed, skipping...

	goto :BIOME_DONE
)

:: get current version
for /f "tokens=2" %%A in ('biome version ^| findstr /b "CLI:"') do (
	set B_CURR=%%A
)

echo Updating biome...

:: get latest version
echo Checking latest version...

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

echo Updating biome from %B_CURR% to %B_NEW%...

curl -Ls https://github.com/biomejs/biome/releases/download/@biomejs/biome@%B_NEW%/biome-win32-x64.exe -o "%USERPROFILE%\.bin\biome.exe" >nul

:BIOME_DONE

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

echo Done.

endlocal

if %0 == "%~0" (
    pause >nul
)
