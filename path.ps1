$managed = @(
    "$HOME\.bin"
    "$HOME\.zig"
)

$managed = @(
    $managed | Where-Object {
        Test-Path -LiteralPath $_ -PathType Container
    }
)

$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment", $true)

try {
    $raw = [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames

    $current = [string]$key.GetValue("Path", "", $raw)
    $previous = [string]$key.GetValue("ENV_REPO_PATHS", "", $raw)

    $previousEntries = @($previous -split ";" | Where-Object { $_ })
    $unmanaged = @($current -split ";" | Where-Object { $_ -and ($_ -notin $previousEntries) })

    $updated = ($unmanaged + $managed | Select-Object -Unique) -join ";"

    $key.SetValue("Path", $updated, [Microsoft.Win32.RegistryValueKind]::ExpandString)
}
finally {
    $key.Dispose()
}

[Environment]::SetEnvironmentVariable("ENV_REPO_PATHS", ($managed -join ";"), "User")
