function Set-SystemTheme {
    [OutputType([void])]
    param(
        [ValidateSet("Light", "Dark")]
        [string] $Theme
    )

    process {
        if ($IsWindows) {
            $Personalize = "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
            $RegistryPath = Get-ItemProperty -Path "Registry::$Personalize"
            $RegistryPath | Set-ItemProperty -Name "AppsUseLightTheme" -Value ([int]($Theme -eq "Light"))
        } elseif ($IsLinux) {
            Write-Error $OperatingSystemNotSupportedError -Category NotImplemented -ErrorAction Stop
        } elseif ($IsMacOS) {
            $IsDarkTheme = $Theme -eq "Dark"
            osascript -e "tell application `"System Events`" to tell appearance preferences to set dark mode to $IsDarkTheme"
        } else {
            Write-Error $OperatingSystemNotSupportedError -Category NotImplemented -ErrorAction Stop
        }
    }
}
