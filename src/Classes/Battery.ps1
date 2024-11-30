[NoRunspaceAffinity()]
class Battery {
    [int] $ChargeRemaining
    [TimeSpan] $Runtime
    [bool] $IsCharging
    [string] $Status

    Battery([int] $ChargeRemaining, [TimeSpan] $Runtime, [bool] $IsCharging, [string] $Status) {
        $this.ChargeRemaining = $ChargeRemaining
        $this.Runtime = $Runtime
        $this.IsCharging = $IsCharging
        $this.Status = $Status
    }
}
