using namespace System
using namespace System.Collections.ObjectModel
using namespace System.Management.Automation

function Set-PowerState {
    <#
        .SYNOPSIS
        Sets the power state of the system to either Hibernate or Suspend.

        .DESCRIPTION
        This function adjusts the power state of the system based on the specified
        power mode and allows for optional parameters to handle wake events and
        force the operation.

        .PARAMETER PowerState
        Specifies the desired power state.

        .PARAMETER DisableWake
        Disables all wake events to prevent the system from waking
        automatically during sleep or hibernation. This parameter is only available
        on Windows operating systems.

        .PARAMETER Force
         Forces the power state change, bypassing confirmations or warnings.

        .INPUTS
        None. You can't pipe objects to Set-PowerState.

        .EXAMPLE
        PS> Set-PowerState

        Sets the power state to suspend.

        .EXAMPLE
        PS> Set-PowerState -PowerState Hibernate -DisableWake -Force

        Puts the system into suspend mode and disables all wake events.

        .OUTPUTS
        None. This function does not produce any output.
    #>
    [OutputType([void])]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param(
        [ValidateSet("Hibernate", "Suspend")]
        [Parameter(Position = 0)]
        [string] $PowerState = "Suspend",

        [switch] $Force
    )

    dynamicparam {
        $ParameterDictionary = [RuntimeDefinedParameterDictionary]::new()

        if ($IsWindows) {
            $DisableWakeAttribute = [ParameterAttribute]::new()
            $DisableWakeAttribute.HelpMessage = "Disables all wake events."

            $AttributeCollection = [Collection[Attribute]]::new()
            $AttributeCollection.Add($DisableWakeAttribute)

            $DisableWakeParameter = [RuntimeDefinedParameter]::new("DisableWake", [switch], $AttributeCollection)

            $ParameterDictionary.Add("DisableWake", $DisableWakeParameter)
        }

        return $ParameterDictionary
    }
    process {
        if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, $PowerState)) {
            if ($IsWindows) {
                Add-Type -AssemblyName System.Windows.Forms
                $PowerState = $PowerState -eq "Hibernate" ? [System.Windows.Forms.PowerState]::Hibernate : [System.Windows.Forms.PowerState]::Suspend
                [System.Windows.Forms.Application]::SetSuspendState($PowerState, $Force, $DisableWake)
            } elseif ($IsLinux) {
                systemctl $State.ToLower() $($Force ? "--force" : [string]::Empty)
            } elseif ($IsMacOS) {
                sudo pmset -a hibernatemode $($State -eq "Hibernate" ? 25 : 3)
                pmset sleepnow
            } else {
                Write-Error $OperatingSystemNotSupportedError -Category NotImplemented -ErrorAction Stop
            }
        }
    }
}
