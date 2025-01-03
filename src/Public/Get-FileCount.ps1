using namespace System.IO

function Get-FileCount {
    <#
        .SYNOPSIS
        Returns the total number of files in one or more directories.

        .DESCRIPTION
        Returns the total number of files in one or more directories.
        By default, the result will includes files from all subdirectories as well, unless
        the search parameter is specified otherwise.

        .PARAMETER Path
        One or more paths to directories for which the file count will be retrieved.
        This parameter is mandatory and supports pipeline input.

        .PARAMETER SearchOption
        Specifies whether to include all subdirectories or only the top-level directory when counting files.
        The default value is [SearchOption]::AllDirectories.

        .INPUTS
        System.String[]. Accepts an array of strings representing directory paths.

        .EXAMPLE
        PS> Get-FileCount -Path $home/Desktop

        Counts all files present on the desktop.

        .EXAMPLE
        PS> "src", "docs" | Get-FileCount

        Counts all files in the "src" and "docs" folder separately.

        .OUTPUTS
        System.Int32. The function outputs the count of files as an integer for each specified path.
    #>
    [OutputType([int])]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [string[]] $Path,

        [Parameter(Position = 1)]
        [SearchOption] $SearchOption = [SearchOption]::AllDirectories
    )

    process {
        foreach ($p in $Path) {
            $FileCount = [Directory]::GetFiles([Path]::Combine($PWD, $p), "*", $SearchOption).Length
            Write-Output $FileCount
        }
    }
}
