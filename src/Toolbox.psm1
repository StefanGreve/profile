#region Export Functions

$Classes = @(Get-ChildItem -Path "${PSScriptRoot}\Classes\*.ps1" -ErrorAction SilentlyContinue)
$Public = @(Get-ChildItem -Path "${PSScriptRoot}\Public\*.ps1" -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path "${PSScriptRoot}\Private\*.ps1" -ErrorAction SilentlyContinue)

foreach ($Import in @($Classes + $Public + $Private)) {
    try {
        . $Import.FullName
    }
    catch {
        Write-Error -Message "Failed to import function $($Import.FullName): $_"
    }
}

Export-ModuleMember -Function $Public.BaseName -Cmdlet * -Alias *

#endregion
