function Get-Battery {
    [Alias("battery")]
    [OutputType([Battery])]
    param()

    process {
        $Battery =  if ($IsWindows) {
            $Win32Battery = Get-CimInstance -ClassName Win32_Battery
            $ChargeRemaining = $Win32Battery.EstimatedChargeRemaining

            # An unhandled 32-bit integer overflow is the reason why Win32_Battery
            # sometimes reports (2^32)/60 as the estimated runtime. This property
            # will only yield an estimate if the utility power is off, is lost and
            # remains off, or if a laptop is disconnected from a power source.
            $Minutes = $Win32Battery.EstimatedRunTime ?? 0
            $IsCharging = $Minutes -eq 0x04444444 -or ($Win32Battery.BatteryStatus -ge 6 -and $Win32Battery.BatteryStatus -le 9)
            $Runtime = New-TimeSpan -Minutes $($IsCharging ? 0 : $Minutes)

            # The first two statuses were renamed to reduce ambiguity.
            # The second status indicates whether a device has access to AC, which
            # means that no battery is being discharged. However, the battery is
            # not necessarily charging, either.
            $Status = switch ($Win32Battery.BatteryStatus) {
                1 { "Discharging" } # Other
                2 { "Connected to AC" } # Unknown
                3 { "Fully Charged" }
                4 { "Low" }
                5 { "Critical" }
                6 { "Charging" }
                7 { "Charging and High" }
                8 { "Charging and Low" }
                9 { "Charging and Critical" }
                10 { "Undefined" }
                11 { "Partially Charged" }
                Default { "Unknown" }
            }

            return [Battery]::new($ChargeRemaining, $Runtime, $IsCharging, $Status)
        } elseif ($IsMacOS) {
            $BatteryInformation = system_profiler SPPowerDataType

            # The second 'Charging:' line comes from the AC Charger Information, and not the Battery Information section
            $IsCharging = $($BatteryInformation | grep "Charging:" | head -n 1 | awk -F ": " '{print ($2 == "Yes" ? 1 : 0)}') -eq 1
            $ChargeRemaining = system_profiler SPPowerDataType | grep "State of Charge (%)" | awk -F": " '{print $2}'

            # The battery status will be displayed in order of (perceived) importance, and is a subset of the possible values
            # that could be returned on Windows
            $IsFullyCharged = $($BatteryInformation | grep "Fully Charged:" | awk -F ": " '{print ($2 == "Yes" ? 1 : 0)}') -eq 1
            $IsConnected = $($BatteryInformation | grep "Connected:" | awk -F ": " '{print ($2 == "Yes" ? 1 : 0)}') -eq 1
            $Condition = $BatteryInformation | grep "Condition:" | awk -F ": " '{print $2}'

            # TODO
            $Runtime = New-TimeSpan -Minutes 0

            $Status = $IsFullyCharged `
                ? "Fully Charged" `
                : $IsConnected `
                ? "Connected to AC" `
                : $Condition

            return [Battery]::new($ChargeRemaining, $Runtime, $IsCharging, $Status)
        } else {
            Write-Error $OperatingSystemNotSupportedError -Category NotImplemented -ErrorAction Stop
        }

        Write-Output $Battery
    }
}
