function Copy-FilePath {
    [OutputType([void])]
    param (
        [Parameter(Position = 0, Mandatory)]
        [string] $Path
    )

    process {
        $FullName = $(Get-Item $Path).FullName
        Set-Clipboard -Value $FullName
    }
}
