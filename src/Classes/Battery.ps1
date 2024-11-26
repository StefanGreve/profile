class Battery {
    [int] $ChargeRemaining
    [timespan] $Runtime
    [bool] $IsCharging
    [string] $Status

    Battery([int] $ChargeRemaining, [timespan] $Runtime, [bool] $IsCharging, [string] $Status) {
        $this.ChargeRemaining = $ChargeRemaining
        $this.Runtime = $Runtime
        $this.IsCharging = $IsCharging
        $this.Status = $Status
    }
}
