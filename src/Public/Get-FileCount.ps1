using namespace System.IO

function Get-FileCount {
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
