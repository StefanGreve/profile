function Test-Command {
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    process {
        $PrevPreference = $ErrorActionPreference

        try {
            $ErrorActionPreference = "Stop"
            Get-Command $Name | Out-Null
            return $true
        }
        catch {
            return $false
        }
        finally {
            $ErrorActionPreference = $PrevPreference
        }
    }
}
