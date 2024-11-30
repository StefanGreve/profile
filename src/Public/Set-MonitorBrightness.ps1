function Set-MonitorBrightness {
    [OutputType([void])]
    param(
        [ValidateRange(0, 100)]
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
                Write-Error "This computer may not support software-based brightness adjustments. Try updating your display adapter drivers to resolve the issue." -Category DeviceError -ErrorAction Stop
            } finally {
                $WmiMonitor.Dispose()
            }
        } elseif ($IsLinux) {
            Write-Error $OperatingSystemNotSupportedError -Category NotImplemented -ErrorAction Stop
        } elseif ($IsMacOS) {
            Write-Error $OperatingSystemNotSupportedError -Category NotImplemented -ErrorAction Stop
        } else {
            Write-Error $OperatingSystemNotSupportedError -Category NotImplemented -ErrorAction Stop
        }
    }
}
