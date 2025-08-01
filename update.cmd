@echo off

REM rio config
xcopy "rio" "%LOCALAPPDATA%\rio" /E /I /Y

REM clink config
xcopy "clink" "%LOCALAPPDATA%\clink" /E /I /Y

REM starship config
copy "starship\starship.toml" "%USERPROFILE%\.config\starship.toml"

REM install starship
where starship >nul 2>&1

if errorlevel 1 (
    echo Installing starship...
    winget install --id Starship.Starship
)

REM install coreutils
where coreutils >nul 2>&1

if errorlevel 1 (
    echo Installing coreutils...
    winget install uutils.coreutils
)

REM install ripgrep
where rg >nul 2>&1

if errorlevel 1 (
    echo Installing ripgrep...
    winget install BurntSushi.ripgrep.MSVC
)

pause