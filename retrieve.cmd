@echo off

:: rio config
echo Retrieving rio config...

if exist "%LOCALAPPDATA%\rio" (
    copy "%LOCALAPPDATA%\rio\config.toml" "rio\config.toml"
)

:: clink config
echo Retrieving clink config...

if exist "%LOCALAPPDATA%\clink" (
	copy "%LOCALAPPDATA%\clink\clink_settings" "clink\clink_settings"
	copy "%LOCALAPPDATA%\clink\init.lua" "clink\init.lua"
	copy "%LOCALAPPDATA%\clink\commands.lua" "clink\commands.lua"
)

:: starship config
echo Retrieving starship config...

if exist "%USERPROFILE%\.config\starship.toml" (
	copy "%USERPROFILE%\.config\starship.toml" "starship\starship.toml"
)

:: biome config
echo Retrieving biome config...

if exist "%USERPROFILE%\biome.json" (
	copy "%USERPROFILE%\biome.json" "biome\biome.json"
)

echo Done.

if %0 == "%~0" (
    pause >nul
)
