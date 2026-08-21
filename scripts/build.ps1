using namespace System.IO

param(
    [string] $ModuleName = "PowerTools",

    [string] $Author = "Stefan Greve",

    [string] $CompanyName = "Advanced Systems",

    [string] $Description = "General purpose Cmdlets for all platforms.",

    [int] $FoundingYear = 2024,

    [ValidateSet("7.4", "7.5", "7.6")]
    [string] $PowerShellVersion = "7.4",

    [Parameter(Mandatory)]
    [string] $Version
)

begin {
    $ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
    Push-Location $([Path]::Join($ProjectRoot, "src"))

    $Steps = 4
    $ManifestPath = "${ModuleName}.psd1"
}
process {
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

    $CurrentYear = [DateTime]::Today.Year
    $YearSpan = $CurrentYear -gt $FoundingYear ? "${FoundingYear} - ${CurrentYear}" : "${FoundingYear}"
    $Copyright = "(c) ${YearSpan} ${CompanyName}. All rights reserved."

    $ManifestArgs = @{
        RootModule = "${ModuleName}.psm1"
        Author = $Author
        Copyright = $Copyright
        CompanyName = $CompanyName
        Description = $Description
        ModuleVersion = $Version
        PowerShellVersion = $PowerShellVersion
        Path = $ManifestPath
        FunctionsToExport = @($FunctionsToExport)
        AliasesToExport = @($Aliases)
        FileList = @($FileList)
        FormatsToProcess = @($Formats)
        ScriptsToProcess = @($Scripts)
    }

    Update-ModuleManifest @ManifestArgs -ErrorAction Stop
    $Module = Import-PowerShellDataFile -Path $ManifestPath
    $Module | Write-Output | Format-Table

    Write-Host "[2/${Steps}] " -ForegroundColor DarkGray -NoNewline
    Write-Host "Test Module Manifest"
    Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop
    Write-Host

    Write-Host "[3/${Steps}] " -ForegroundColor DarkGray -NoNewline
    Write-Host "Import Module"
    Write-Host

    Import-Module -Name "./${ManifestPath}" -Force -ErrorAction Stop

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
