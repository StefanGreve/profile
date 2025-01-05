function Get-Definition {
    <#
        .SYNOPSIS
        Prints the definition of a specified PowerShell function or Cmdlet.

        .DESCRIPTION
        Prints the definition of a specified PowerShell function or Cmdlet.
        If the command is a PowerShell script or function, the source code of the script or function is returned.
        Otherwise, for commands from binary modules, the syntax of the command is displayed.

        .PARAMETER Command
        The name of the PowerShell command.

        .INPUTS
        None. You can't pipe objects to Get-Definition.

        .EXAMPLE
        PS> Get-Definition Get-Battery

        Returns the implementation of the Get-Battery Cmdlet.

        .OUTPUTS
        The definition of the specified command is returned as a string.

        .NOTES
        If the bat syntax highlighter is installed and accessible, it formats the output.
    #>
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
