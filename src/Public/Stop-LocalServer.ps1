function Stop-LocalServer {
    [OutputType([void])]
    [CmdletBinding(ConfirmImpact = "High", SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [int] $Port
    )

    process {
        $TcpConnection = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue

        if ($null -eq $TcpConnection) {
            Write-Error "No owning process found listening on port ${Port}." -Category ConnectionError -ErrorAction Stop
            return
        }

        $Process = Get-Process -Id $TcpConnection.OwningProcess

        if ($PSCmdlet.ShouldProcess("Stop Process", "Are you sure that you want to stop this process with force?", "Stopping Process with ID=$($Process.Id) (Process Name: $($Process.ProcessName))")) {
            Stop-Process $Process -Force -ErrorAction Stop
        }
    }
}
