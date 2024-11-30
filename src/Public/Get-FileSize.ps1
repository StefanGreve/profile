function Get-FileSize {
    [OutputType([double])]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [string[]] $Path,

        [Parameter(Position = 1)]
        [ValidateSet("B", "KiB", "MiB", "GiB", "TiB", "PiB")]
        [string] $Unit = "B"
    )

    process {
        foreach ($p in $Path) {
            $Bytes = [Math]::Abs($(Get-Item $p).Length)

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
