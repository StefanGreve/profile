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
    #>
    [OutputType([void])]
    [CmdletBinding()]
    param(
        [ValidateRange(0, 100)]
        [Parameter(Position = 0)]
        [int] $Brightness
    )

    process {
        if ($IsWindows) {
            $Timeout = 1 # in seconds
            $WmiMonitor = Get-CimInstance -Namespace root/WMI -Class WmiMonitorBrightnessMethods

            try {
                $WmiMonitor.WmiSetBrightness($Timeout, $Brightness)
            }
            catch {
                Write-Error "This computer may not support software-based brightness adjustments. Try updating your display adapter drivers to resolve the issue." `
                    -Category DeviceError `
                    -ErrorAction Stop
            } finally {
                $WmiMonitor.Dispose()
            }
        } else {
            Write-Error $OperatingSystemNotSupportedError `
                -Category NotImplemented `
                -ErrorAction Stop
        }
    }
}
