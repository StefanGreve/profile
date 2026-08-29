function Set-SystemTheme {
    <#
        .SYNOPSIS
        Sets the theme of the operating system.

        .DESCRIPTION
        This function changes the appearance theme of the operating system to either
        Light or Dark.

        .PARAMETER Theme
        Specifies the desired system theme.
        Accepted values are "Light" and "Dark".

        .INPUTS
        None. You can't pipe objects to Set-SystemTheme.

        .OUTPUTS
        None. This function does not produce any output.

        .EXAMPLE
        PS> Set-SystemTheme Dark
    #>
    [OutputType([void])]
    [CmdletBinding()]
    param(
        [ValidateSet("Light", "Dark")]
        [Parameter(Position = 0)]
        [string] $Theme
    )

    process {
        if ($IsWindows) {
            $Personalize = "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
            $RegistryPath = Get-ItemProperty -Path "Registry::$Personalize"
            $RegistryPath | Set-ItemProperty -Name "AppsUseLightTheme" -Value ([int]($Theme -eq "Light"))
        } elseif ($IsLinux) {
            $ErrorRecord = New-TerminatingErrorRecord -Message $OperatingSystemNotSupportedError -Category NotImplemented -ErrorId "OperatingSystemNotSupported"
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        } elseif ($IsMacOS) {
            $IsDarkTheme = $Theme -eq "Dark"
            # osascript echoes the result of its last statement; a 'set' yields the assigned
            # value, so discard it to honor the [void] contract on macOS.
            osascript -e "tell application `"System Events`" to tell appearance preferences to set dark mode to $IsDarkTheme" | Out-Null
        } else {
            $ErrorRecord = New-TerminatingErrorRecord -Message $OperatingSystemNotSupportedError -Category NotImplemented -ErrorId "OperatingSystemNotSupported"
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }
    }
}
