param(
    [switch] $Uninstall,
    [switch] $CmdOnly
)

$ErrorActionPreference = "Stop"

$progId = "Rio.CmdFile"
$progIdRoot = "HKCU:\Software\Classes\$progId"

function Refresh-ShellAssociations {
    $signature = @"
using System;
using System.Runtime.InteropServices;

public static class ShellNotify {
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(
        uint wEventId,
        uint uFlags,
        IntPtr dwItem1,
        IntPtr dwItem2
    );
}
"@

    Add-Type -TypeDefinition $signature -ErrorAction SilentlyContinue
    [ShellNotify]::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)
}

function Register-Association {
    param(
        [Parameter(Mandatory)]
        [string] $Extension
    )

    $extensionKey = "HKCU:\Software\Classes\$Extension"
    New-Item -Path $extensionKey -Force | Out-Null
    Set-Item -Path $extensionKey -Value $progId

    $openWithKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\OpenWithProgids"
    New-Item -Path $openWithKey -Force | Out-Null
    New-ItemProperty -Path $openWithKey -Name $progId -PropertyType None -Value ([byte[]]@()) -Force | Out-Null
}

function Remove-Association {
    param(
        [Parameter(Mandatory)]
        [string] $Extension
    )

    $extensionKey = "HKCU:\Software\Classes\$Extension"

    if (Test-Path $extensionKey) {
        $currentProgId = (Get-Item $extensionKey).GetValue("")

        if ($currentProgId -eq $progId) {
            Remove-Item $extensionKey -Recurse -Force
        }
    }

    $openWithKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\OpenWithProgids"

    if (Test-Path $openWithKey) {
        Remove-ItemProperty -Path $openWithKey -Name $progId -ErrorAction SilentlyContinue
    }
}

if ($Uninstall) {
    Remove-Association ".cmd"

    if (-not $CmdOnly) {
        Remove-Association ".bat"
    }

    if (Test-Path $progIdRoot) {
        Remove-Item $progIdRoot -Recurse -Force
    }

    Refresh-ShellAssociations

    Write-Host "Rio command-script handler removed."

    exit 0
}

$rioCommand = Get-Command "rio.exe" -ErrorAction SilentlyContinue

if ($null -eq $rioCommand) {
    $candidatePaths = @(
        (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links\rio.exe"),
        (Join-Path $env:USERPROFILE "scoop\shims\rio.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Rio\rio.exe"),
        (Join-Path $env:ProgramFiles "Rio\rio.exe")
    )

    foreach ($candidatePath in $candidatePaths) {
        if (Test-Path $candidatePath) {
            $rioCommand = Get-Item $candidatePath
            break
        }
    }
}

if ($null -eq $rioCommand) {
    throw "Could not find rio.exe. Make sure Rio is installed and available in PATH."
}

$rioPath = $rioCommand.Source

if ([string]::IsNullOrWhiteSpace($rioPath)) {
    $rioPath = $rioCommand.FullName
}

$cmdPath = $env:ComSpec

if ([string]::IsNullOrWhiteSpace($cmdPath) -or -not (Test-Path $cmdPath)) {
    $cmdPath = Join-Path $env:SystemRoot "System32\cmd.exe"
}

$commandKey = Join-Path $progIdRoot "shell\open\command"
$openCommand = "`"$rioPath`" -e `"$cmdPath`" /d /k call `"%1`" %*"

New-Item -Path $commandKey -Force | Out-Null
Set-Item -Path $progIdRoot -Value "Command Script (Rio)"
Set-Item -Path $commandKey -Value $openCommand

Register-Association ".cmd"

if (-not $CmdOnly) {
    Register-Association ".bat"
}

Refresh-ShellAssociations

Write-Host ""
Write-Host "Installed Rio command-script handler."
Write-Host "Rio: $rioPath"
Write-Host ""
Write-Host "Uninstall with:"
Write-Host "  powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Uninstall"
