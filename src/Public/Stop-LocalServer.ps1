function Stop-LocalServer {
    <#
        .SYNOPSIS
        Stops a local server process that is listening on a specified TCP port.

        .DESCRIPTION
        This function identifies and forcefully stops the process that owns a specified
        TCP port.

        .PARAMETER Port
        Specifies the local TCP port to check for an active connection. The process that owns
        this port will be terminated if found.

        .INPUTS
        None. You can't pipe objects to Stop-LocalServer.

        .EXAMPLE
        PS> Stop-LocalServer -Port 8080

        Identifies the process listening on port 8080 and prompts the user before stopping it.

        .OUTPUTS
        None. This function does not produce any output.
    #>
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
