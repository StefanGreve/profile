function Copy-FilePath {
    <#
        .SYNOPSIS
        Copies the full path of a file to clipboard.

        .DESCRIPTION
        Copies the full path of a file to clipboard.
        Takes any string for file paths that exists.

        .PARAMETER Path
        Specifies the file path.

        .INPUTS
        None. You can't pipe objects to Copy-FilePath.

        .EXAMPLE
        PS> Copy-FilePath ./src/README.md

        Copies the full path of the README.md file to clipboard.

        .OUTPUTS
        None. This function does not produce any output.
    #>
    [OutputType([void])]
    param (
        [Parameter(Position = 0, Mandatory)]
        [string] $Path
    )

    process {
        $Item = Get-Item $Path
        Set-Clipboard -Value $Item.FullName
    }
}
