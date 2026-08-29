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
        System.Int32. You can pipe a port number to Stop-LocalServer.

        .OUTPUTS
        None. This function does not produce any output.

        .NOTES
        Without elevation, only processes owned by the current user can be resolved and
        stopped: on Windows this requires an elevated session, and on macOS and Linux
        'lsof' must run under 'sudo'. A server started under a different account will
        therefore not be found unless the function is run with the necessary privileges.

        .EXAMPLE
        PS> Stop-LocalServer -Port 8080

        Identifies the process listening on port 8080 and prompts the user before stopping it.
    #>
    [OutputType([void])]
    [CmdletBinding(ConfirmImpact = "High", SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [int] $Port
    )

    process {
        [int[]] $ProcessIds = if ($IsWindows) {
            # A single port can be held by more than one connection (e.g. IPv4 and IPv6),
            # so collect every distinct owning process and stop all of them.
            Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
                | Select-Object -ExpandProperty OwningProcess
                | Select-Object -Unique
        } else {
            # -t: terse output (PIDs only), -sTCP:LISTEN: only listening sockets.
            # lsof exits non-zero and prints nothing when no process owns the port.
            lsof -nP -iTCP:$Port -sTCP:LISTEN -t 2>$null | Select-Object -Unique
        }

        if ($null -eq $ProcessIds -or $ProcessIds.Count -eq 0) {
            Write-Error "No owning process found listening on port ${Port}." `
                -Category ConnectionError `
                -ErrorId "NoProcessOnPort" `
                -TargetObject $Port
            return
        }

        foreach ($ProcessId in $ProcessIds) {
            $Process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue

            if ($null -eq $Process) { continue }

            if ($PSCmdlet.ShouldProcess("Process ID=$($Process.Id) (Name: $($Process.ProcessName)) on port ${Port}", "Are you sure you want to force-stop this process?", "Stop Process")) {
                try {
                    Stop-Process -InputObject $Process -Force -ErrorAction Stop
                } catch {
                    Write-Error "Failed to stop process ID=$($Process.Id) (Name: $($Process.ProcessName)) on port ${Port}: $($_.Exception.Message)" `
                        -Category $_.CategoryInfo.Category `
                        -ErrorId "StopProcessFailed" `
                        -TargetObject $Process
                }
            }
        }
    }
}
