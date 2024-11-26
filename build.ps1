param(
    [string] $ModuleName = "Toolbox"
)

begin {
    Push-Location "src"

    $Steps = 3
    $ManifestPath = "${ModuleName}.psd1"
}
process {
    #region Step 1 - Test Module Manifest

    Write-Host "[1/${Steps}] " -ForegroundColor DarkGray -NoNewline
    Write-Host "Test Module Manifest"
    Test-ModuleManifest -Path $ManifestPath
    Write-Host

    #endregion

    #region Step 2 - Update Manifest

    Write-Host "[2/${Steps}] " -ForegroundColor DarkGray -NoNewline
    Write-Host "Update Manifest"

    $FunctionsToExport = Get-ChildItem -Path "./Public" -Filter "*.ps1"
        | Select-Object -ExpandProperty BaseName

    $FileList = Get-ChildItem -Recurse -Path "."
        | Where-Object { ! $_.PSIsContainer }
        | Select-Object -ExpandProperty FullName
        | Resolve-Path -Relative

    $Classes = Get-ChildItem -Path "Classes" -Filter "*.ps1"
        | Select-Object -ExpandProperty FullName
        | Resolve-Path -Relative

    $ManifestParameter = @{
        Path = $ManifestPath
        FunctionsToExport = @($FunctionsToExport)
        FileList = @($FileList)
        ScriptsToProcess = @($Classes)
    }

    Update-ModuleManifest @ManifestParameter

    #endregion

    #region Step 3 - Import Module

    Write-Host "[3/${Steps}] " -ForegroundColor DarkGray -NoNewline
    Write-Host "Import Module"
    Import-Module -Name "./${ManifestPath}" -Force -Verbose

    #endregion
}
clean {
    Pop-Location
}
