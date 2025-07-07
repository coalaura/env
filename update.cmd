@echo off

REM rio config
xcopy "rio" "%LOCALAPPDATA%\rio" /E /I /Y

REM clink config
xcopy "clink" "%LOCALAPPDATA%\clink" /E /I /Y