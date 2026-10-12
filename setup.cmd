@echo off

setlocal

set "SETUP_EXIT=0"
set "SETUP_IS_ADMIN=0"

net session >nul 2>&1

if errorlevel 1 (
	echo Setup requires admin privileges, relaunching...

	sudo rio -e "setup.cmd"

	if errorlevel 1 set "SETUP_EXIT=1"

	goto :END
)

set "SETUP_IS_ADMIN=1"

:: pull repo
echo Pulling...

git pull

if errorlevel 1 goto :FAIL

:: default binary folder
if not exist "%USERPROFILE%\.bin" (
	mkdir "%USERPROFILE%\.bin"

	if errorlevel 1 goto :FAIL
)

set "PATH=%USERPROFILE%\.bin;%PATH%"
set "TAP_BIN="

if exist "%USERPROFILE%\.bin\tap.exe" set "TAP_BIN=%USERPROFILE%\.bin\tap.exe"

if not defined TAP_BIN (
	for /f "delims=" %%T in ('where tap.exe 2^>nul') do if not defined TAP_BIN set "TAP_BIN=%%T"
)

if defined TAP_BIN goto :UPDATE_TAP

set "TAP_BIN=%USERPROFILE%\.bin\tap.exe"

call :INSTALL_TAP

if errorlevel 1 goto :FAIL

goto :INSTALL_PACKAGES

:UPDATE_TAP

echo Checking for tap updates...

"%TAP_BIN%" tap

if errorlevel 1 goto :FAIL

:INSTALL_PACKAGES

"%TAP_BIN%" get go zig upx starship bun builder vet time wtf coreutils actup license mksvc

if errorlevel 1 goto :FAIL

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0path.ps1"

if errorlevel 1 goto :FAIL

call update.cmd

if errorlevel 1 goto :FAIL

goto :END

:INSTALL_TAP

set "TAP_TMP=%USERPROFILE%\.bin\.tap-%RANDOM%-%RANDOM%"

mkdir "%TAP_TMP%"

if errorlevel 1 exit /b 1

echo Checking the latest tap release...

curl.exe -fsSL --connect-timeout 15 --max-time 60 -o NUL -w "%%{url_effective}" "https://github.com/coalaura/tap/releases/latest" >"%TAP_TMP%\release"

if errorlevel 1 goto :TAP_INSTALL_FAILED

set "TAP_RELEASE="
set "TAP_VERSION="
set /p TAP_RELEASE=<"%TAP_TMP%\release"

for /f "tokens=7 delims=/" %%V in ("%TAP_RELEASE%") do set "TAP_VERSION=%%V"

if not defined TAP_VERSION goto :TAP_INSTALL_FAILED

set "TAP_RELEASE=https://github.com/coalaura/tap/releases/download/%TAP_VERSION%"

echo Installing tap %TAP_VERSION%...

curl.exe -fsSL --connect-timeout 15 --max-time 900 -o "%TAP_TMP%\tap.exe" "%TAP_RELEASE%/tap-windows-amd64.exe"

if errorlevel 1 goto :TAP_INSTALL_FAILED

curl.exe -fsSL --connect-timeout 15 --max-time 900 -o "%TAP_TMP%\SHA256SUMS" "%TAP_RELEASE%/SHA256SUMS"

if errorlevel 1 goto :TAP_INSTALL_FAILED

powershell.exe -NoProfile -Command "$expected = @(Get-Content -LiteralPath ($env:TAP_TMP + '\SHA256SUMS') | Where-Object { $_ -match '^[0-9a-fA-F]{64} [ *]tap-windows-amd64\.exe$' }); if ($expected.Count -ne 1) { exit 1 }; $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath ($env:TAP_TMP + '\tap.exe')).Hash; if ($actual -ine $expected[0].Substring(0, 64)) { exit 1 }"

if errorlevel 1 (
	echo Failed to verify tap

	goto :TAP_INSTALL_FAILED
)

move /y "%TAP_TMP%\tap.exe" "%TAP_BIN%" >nul

if errorlevel 1 goto :TAP_INSTALL_FAILED

rmdir /s /q "%TAP_TMP%"

exit /b 0

:TAP_INSTALL_FAILED

echo Failed to install tap

rmdir /s /q "%TAP_TMP%"

exit /b 1

:FAIL

set "SETUP_EXIT=1"

:END

if "%SETUP_EXIT%"=="0" goto :EXIT
if not "%SETUP_IS_ADMIN%"=="1" goto :EXIT

echo %CMDCMDLINE% | findstr /i /c:" /c" >nul

if errorlevel 1 goto :EXIT

echo Setup failed. Press any key to close...
pause >nul

:EXIT

endlocal & exit /b %SETUP_EXIT%
