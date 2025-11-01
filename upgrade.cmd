@echo off

setlocal enabledelayedexpansion

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
