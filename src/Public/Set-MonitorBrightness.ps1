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
        On Windows, the function relies on WMI (root/WMI WmiMonitorBrightnessMethods). On macOS, it
        calls into CoreGraphics and the DisplayServices framework, which ship with the operating
        system, so no additional tooling is required. Linux is not supported and raises a
        NotImplemented error.

        Both implementations address the internal panel: WmiMonitorBrightnessMethods only exposes it,
        and DisplayServices cannot drive external monitors, because those expect DDC/CI instead. When
        "Automatically adjust brightness" is enabled on macOS, ambient light compensation may override
        the requested level shortly after it was applied.
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
        } elseif ($IsMacOS) {
            if (-not ("PowerTools.Native.DisplayServices" -as [Type])) {
                # Compiled on demand: the module is imported on every shell start, and this costs
                # about 140 ms that only a caller on macOS should ever pay.
                Add-Type -Namespace PowerTools.Native -Name DisplayServices -MemberDefinition @"
private const string CoreGraphicsPath = "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics";
private const string DisplayServicesPath =
    "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices";

[DllImport(CoreGraphicsPath)]
public static extern uint CGMainDisplayID();

[DllImport(CoreGraphicsPath)]
public static extern int CGGetActiveDisplayList(uint maxDisplays, uint[] activeDisplays, out uint displayCount);

// The default marshalling for bool is the four byte Win32 BOOL, whereas a C bool is one byte on Darwin.
[DllImport(CoreGraphicsPath)]
[return: MarshalAs(UnmanagedType.I1)]
public static extern bool CGDisplayIsBuiltin(uint display);

[DllImport(DisplayServicesPath)]
[return: MarshalAs(UnmanagedType.I1)]
public static extern bool DisplayServicesCanChangeBrightness(uint display);

[DllImport(DisplayServicesPath)]
public static extern int DisplayServicesSetBrightness(uint display, float brightness);
"@
            }

            $MaxDisplays = 32
            $ActiveDisplays = [uint32[]]::new($MaxDisplays)
            $DisplayCount = [uint32] 0

            $Result = [PowerTools.Native.DisplayServices]::CGGetActiveDisplayList(
                $MaxDisplays, $ActiveDisplays, [ref] $DisplayCount)

            if ($Result -ne 0) {
                $Message = "Unable to enumerate the active displays (CGError ${Result})."
                $ErrorRecord = New-TerminatingErrorRecord -Message $Message `
                    -Category DeviceError -ErrorId "DisplayEnumerationFailed"
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }

            $BuiltinDisplay = $ActiveDisplays | Select-Object -First $DisplayCount |
                Where-Object { [PowerTools.Native.DisplayServices]::CGDisplayIsBuiltin($_) } |
                Select-Object -First 1

            $DisplayId = $BuiltinDisplay ?? [PowerTools.Native.DisplayServices]::CGMainDisplayID()

            if (-not [PowerTools.Native.DisplayServices]::DisplayServicesCanChangeBrightness($DisplayId)) {
                $Message = "This display does not support software-based brightness adjustments. " +
                    "External monitors typically expect DDC/CI, which this Cmdlet does not implement."
                $ErrorRecord = New-TerminatingErrorRecord -Message $Message `
                    -Category DeviceError -ErrorId "BrightnessControlUnsupported" -TargetObject $DisplayId
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }

            $Result = [PowerTools.Native.DisplayServices]::DisplayServicesSetBrightness(
                $DisplayId, [float] ($Brightness / 100))

            if ($Result -ne 0) {
                $Message = "Failed to set the brightness of display ${DisplayId} (IOReturn ${Result})."
                $ErrorRecord = New-TerminatingErrorRecord -Message $Message `
                    -Category DeviceError -ErrorId "BrightnessControlFailed" -TargetObject $DisplayId
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }
        } else {
            $ErrorRecord = New-TerminatingErrorRecord -Message $OperatingSystemNotSupportedError -Category NotImplemented -ErrorId "OperatingSystemNotSupported"
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }
    }
}
