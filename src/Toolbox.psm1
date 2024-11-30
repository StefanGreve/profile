#region Export Functions and Classes

$Classes = @(Get-ChildItem -Path "${PSScriptRoot}\Classes\*.ps1" -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path "${PSScriptRoot}\Private\*.ps1" -ErrorAction SilentlyContinue)
$Public = @(Get-ChildItem -Path "${PSScriptRoot}\Public\*.ps1" -ErrorAction SilentlyContinue)

foreach ($Import in @($Classes + $Private + $Public)) {
    try {
        $File = $Import.FullName
        . $File
        Write-Host "[ OK ] " -ForegroundColor Green -NoNewline
        Write-Host "Importing ${File}"
    }
    catch {
        Write-Host "[ ER ] " -ForegroundColor Red -NoNewline
        Write-Host "Failed to import file ${File}: $_"
    }
}

Export-ModuleMember -Function $Public.BaseName -Cmdlet * -Alias *

#endregion
