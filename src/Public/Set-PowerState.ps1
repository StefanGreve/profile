using namespace System
using namespace System.Collections.ObjectModel
using namespace System.Management.Automation

function Set-PowerState {
    [OutputType([void])]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param(
        [ValidateSet("Hibernate", "Suspend")]
        [Parameter(Position = 0)]
        [string] $PowerState = "Suspend",

        [switch] $Force
    )

    dynamicparam {
        $ParameterDictionary = New-Object RuntimeDefinedParameterDictionary

        if ($IsWindows) {
            $DisableWakeAttribute = New-Object ParameterAttribute
            $DisableWakeAttribute.HelpMessage = "Disables all wake events."

            $AttributeCollection = New-Object Collection[Attribute]
            $AttributeCollection.Add($DisableWakeAttribute)

            $DisableWakeParameter = New-Object RuntimeDefinedParameter("DisableWake", [switch], $AttributeCollection)

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
