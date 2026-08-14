using namespace System.IO

param(
    [string] $ModuleName = "PowerTools",

    [Parameter(Mandatory)]
    [string] $Version
)

begin {
    $ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
    Push-Location $([Path]::Combine($ProjectRoot, "src"))

    $Steps = 4
    $ManifestPath = "${ModuleName}.psd1"
}
process {
    # 1 - Update Manifest

    Write-Host "[1/${Steps}] " -ForegroundColor DarkGray -NoNewline
    Write-Host "Update Manifest"

    $FunctionsToExport = Get-ChildItem -Path "./Public" -Filter "*.ps1"
        | Select-Object -ExpandProperty BaseName

    $Aliases = $(Get-ChildItem -Path "./Public" -Filter "*.ps1"
        | Get-Content
        | Select-String -Pattern '\[Alias\("([^"]+)"\)\]').Matches.Groups
        | Where-Object Name -EQ 1
        | Select-Object -ExpandProperty Value

    $FileList = Get-ChildItem -Recurse -Path "."
        | Where-Object { ! $_.PSIsContainer }
        | Select-Object -ExpandProperty FullName
        | Resolve-Path -Relative

    $Formats = Get-ChildItem -Path "./Formats" -Filter "*.ps1xml"
        | Select-Object -ExpandProperty FullName
        | Resolve-Path -Relative

    $Scripts = Get-ChildItem -Path "./Scripts" -Filter "*.ps1"
        | Select-Object -ExpandProperty FullName
        | Resolve-Path -Relative

    $ManifestArgs = @{
        Path = $ManifestPath
        ModuleVersion = $Version
        FunctionsToExport = @($FunctionsToExport)
        AliasesToExport = @($Aliases)
        FileList = @($FileList)
        FormatsToProcess = @($Formats)
        ScriptsToProcess = @($Scripts)
    }

    Update-ModuleManifest @ManifestArgs -ErrorAction Stop
    $Module = Import-PowerShellDataFile -Path $ManifestPath
    $Module | Write-Output | Format-Table

    # 2 - Test Module Manifest

    Write-Host "[2/${Steps}] " -ForegroundColor DarkGray -NoNewline
    Write-Host "Test Module Manifest"
    Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop
    Write-Host

    # 3 - Import Module

    Write-Host "[3/${Steps}] " -ForegroundColor DarkGray -NoNewline
    Write-Host "Import Module"
    Write-Host

    Import-Module -Name "./${ManifestPath}" -Force -ErrorAction Stop

    # 4 - Run Analyzer

    Write-Host "[4/${Steps}] " -ForegroundColor DarkGray -NoNewline
    Write-Host "Run Analyzer"
    Write-Host

    if (!$(Get-Module PSScriptAnalyzer -ListAvailable)) {
        Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
    }

    $ScriptAnalyzerArgs = @{
        Path = "./${ManifestPath}"
        Severity = "Warning"
        Recurse = $true
        ReportSummary = $true
    }

    Import-Module PSScriptAnalyzer
    Invoke-ScriptAnalyzer @ScriptAnalyzerArgs
}
clean {
    Pop-Location
}
