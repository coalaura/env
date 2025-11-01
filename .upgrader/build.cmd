@echo off

if not exist ..\.bin (
	mkdir ..\.bin
)

echo Building windows...

go build -o ..\.bin\upgrader.exe

echo Building linux

set GOOS=linux
go build -o ..\.bin\upgrader
set GOOS=windows

echo Done.
