function Set-MonitorBrightness {
    <#
        .SYNOPSIS
        Adjusts the brightness level of the monitor.

        .DESCRIPTION
        Sets the brightness of the monitor to a specified level. The brightness
        level must be provided as a percentage within the range of 0 to 100.
        The function is designed to work on systems that support programmatic
        brightness adjustments.

        .PARAMETER Brightness
        Specifies the desired brightness level as a percentage.

        .INPUTS
        None. You can't pipe objects to Set-MonitorBrightness. The value must be
        an integer between 0 (minimum brightness) and 100 (maximum brightness).

        .OUTPUTS
        None. This function does not produce any output.

        .EXAMPLE
        PS> Set-MonitorBrightness -Brightness 65

        Sets the monitor brightness to 65%.

        .NOTES
        Only supported on Windows; the function relies on WMI (root/WMI WmiMonitorBrightnessMethods)
        and throws a NotImplemented error on Linux and macOS.
    #>
    [OutputType([void])]
    [CmdletBinding()]
    param(
        [ValidateRange(0, 100)]
        [Parameter(Mandatory, Position = 0)]
        [int] $Brightness
    )

    process {
        if ($IsWindows) {
            $Timeout = 1 # in seconds
            $WmiMonitor = $null

            try {
                $WmiMonitor = Get-CimInstance -Namespace root/WMI -Class WmiMonitorBrightnessMethods

                $null = Invoke-CimMethod -InputObject $WmiMonitor -MethodName WmiSetBrightness `
                    -Arguments @{ Timeout = [uint32] $Timeout; Brightness = [byte] $Brightness }
            }
            catch {
                $ErrorRecord = New-TerminatingErrorRecord -Message "This computer may not support software-based brightness adjustments. Try updating your display adapter drivers to resolve the issue." -Category DeviceError -ErrorId "BrightnessControlUnsupported" -Exception $_.Exception
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            } finally {
                # $WmiMonitor is null when brightness control is unsupported.
                if ($null -ne $WmiMonitor) {
                    $WmiMonitor.Dispose()
                }
            }
        } else {
            $ErrorRecord = New-TerminatingErrorRecord -Message $OperatingSystemNotSupportedError -Category NotImplemented -ErrorId "OperatingSystemNotSupported"
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }
    }
}
