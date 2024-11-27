function Copy-FilePath {
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
