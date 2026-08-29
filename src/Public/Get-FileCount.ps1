using namespace System.IO

function Get-FileCount {
    <#
        .SYNOPSIS
        Returns the total number of files in one or more directories.

        .DESCRIPTION
        Returns the total number of files in one or more directories.
        By default, the result includes files from all subdirectories as well, unless
        the search parameter is specified otherwise.

        .PARAMETER Path
        One or more paths to directories for which the file count will be retrieved.
        This parameter is mandatory and supports pipeline input.

        .PARAMETER SearchOption
        Specifies whether to include all subdirectories or only the top-level directory when counting files.
        The default value is [SearchOption]::AllDirectories.

        .INPUTS
        System.String[]. Accepts an array of strings representing directory paths.

        .OUTPUTS
        System.Int32. The function outputs the count of files as an integer for each specified path.

        .EXAMPLE
        PS> Get-FileCount -Path $home/Desktop

        Counts all files present on the desktop.

        .EXAMPLE
        PS> "src", "docs" | Get-FileCount

        Counts all files in the "src" and "docs" folder separately.
    #>
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Path,

        [Parameter(Position = 1)]
        [SearchOption] $SearchOption = [SearchOption]::AllDirectories
    )

    process {
        foreach ($p in $Path) {
            # Resolve $p against $PWD (not the process CWD that GetFiles would use) and expand ~ and PSDrives.
            $ResolvedPath = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($p)

            # Report a non-terminating error and skip so the remaining pipeline paths still process.
            try {
                $FileCount = [Directory]::GetFiles($ResolvedPath, "*", $SearchOption).Length
            }
            catch [System.IO.DirectoryNotFoundException] {
                Write-Error "The directory `"$p`" does not exist." `
                    -Category ObjectNotFound `
                    -ErrorId "DirectoryNotFound" `
                    -TargetObject $p
                continue
            }
            catch [System.UnauthorizedAccessException] {
                Write-Error "Access to the directory `"$p`" is denied." `
                    -Category PermissionDenied `
                    -ErrorId "DirectoryAccessDenied" `
                    -TargetObject $p
                continue
            }
            catch {
                Write-Error "Failed to count files in `"$p`": $($_.Exception.Message)" `
                    -Category ReadError `
                    -ErrorId "FileCountFailed" `
                    -TargetObject $p
                continue
            }

            Write-Output $FileCount
        }
    }
}
