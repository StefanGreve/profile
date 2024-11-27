function Get-Definition {
    [OutputType([string])]
    param(
        [string] $Command
    )

    process {
        $Definition = $(Get-Command $Command -ErrorAction SilentlyContinue).Definition

        if ($Definition.Length -eq 0) {
            Write-Error "The command `"{$Definition}`" is not recognized as a name of a cmdlet or function." -Category InvalidArgument -ErrorAction Stop
        }

        if (Test-Command bat) {
            Write-Output $Definition | bat --language powershell
        } else {
            Write-Output $Definition
        }
    }
}
