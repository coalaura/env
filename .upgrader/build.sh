#!/bin/bash

mkdir -p ../.bin

echo Building windows...

GOOS=windows go build -o ../.bin/upgrader.exe

echo Building linux...

go build -o ../.bin/upgrader

echo Done.
