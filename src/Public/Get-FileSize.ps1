function Get-FileSize {
    <#
        .SYNOPSIS
        Returns the size of a file in the specified unit of measurement.

        .DESCRIPTION
        Returns the size of a file in the specified unit of measurement.

        .PARAMETER Path
        One or more file paths whose sizes will be calculated.

        This parameter is mandatory and supports pipeline input.

        Each path must refer to a file. Paths that refer to a directory are
        skipped and produce a non-terminating error.

        .PARAMETER Unit
        The unit of measurement for the file size in base 2.
        The default unit is bytes (B).

        .INPUTS
        System.String[]. Accepts an array of strings representing file paths.

        .OUTPUTS
        System.Double. The function outputs the size of each file as a double-precision floating-point number.

        .EXAMPLE
        PS> Get-FileSize $PROFILE

        Returns the size of the PowerShell profile in bytes.

        .EXAMPLE
        PS> "picture1.png", "picture2.png", "picture3.png" | Get-FileSize -Unit MiB | Measure-Object -Sum | Select-Object -ExpandProperty Sum

        Calculates the total file size of all three images in MiB.
    #>
    [OutputType([double])]
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [string[]] $Path,

        [ValidateSet("B", "KiB", "MiB", "GiB", "TiB", "PiB")]
        [Parameter(Position = 1)]
        [string] $Unit = "B"
    )

    process {
        foreach ($p in $Path) {
            $Item = Get-Item -Path $p

            if ($Item.PSIsContainer) {
                Write-Error "The path '$p' refers to a directory, not a file." `
                    -Category InvalidArgument `
                    -ErrorAction Continue

                # also continue with the loop flow, not just the error stream
                continue
            }

            $Bytes = $Item.Length

            $Size = switch ($Unit) {
                "PiB" { $Bytes / 1PB }
                "TiB" { $Bytes / 1TB }
                "GiB" { $Bytes / 1GB }
                "MiB" { $Bytes / 1MB }
                "KiB" { $Bytes / 1KB }
                Default { $Bytes }
            }

            Write-Output $Size
        }
    }
}
