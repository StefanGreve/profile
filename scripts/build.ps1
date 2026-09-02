using namespace System.IO

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ModuleName,

    [Parameter(Mandatory)]
    [string] $Author,

    [Parameter(Mandatory)]
    [string] $CompanyName,

    [Parameter(Mandatory)]
    [string] $Description,

    [Parameter(Mandatory)]
    [int] $FoundingYear,

    [hashtable] $PrivateData = @{},

    [ValidateSet("7.4", "7.5", "7.6", "7.7")]
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

    # Update-ModuleManifest discards the PSData it receives through -PrivateData (it re-reads the copy
    # in the manifest on disk instead), so the well-known keys have to travel as discrete parameters.
    $PSDataParameters = @(
        "Tags",
        "LicenseUri",
        "IconUri",
        "ProjectUri",
        "ReleaseNotes",
        "Prerelease",
        "ExternalModuleDependencies"
    )

    $PSData = $PrivateData["PSData"] ?? @{}

    if ($PSData -isnot [hashtable]) {
        Write-Error "The PSData entry of PrivateData must be a hashtable." -Category InvalidArgument -ErrorAction Stop
    }

    foreach ($Key in $PSData.Keys) {
        if ($PSDataParameters -contains $Key) {
            $ManifestArgs[$Key] = $PSData[$Key]
        }
        elseif ($Key -eq "RequireLicenseAcceptance") {
            if ($PSData[$Key]) {
                $ManifestArgs.RequireLicenseAcceptance = $true
            }
        }
        else {
            Write-Warning "Ignoring unsupported PSData key '${Key}' (Update-ModuleManifest drops it silently)."
        }
    }

    $ModulePrivateData = @{}

    foreach ($Key in @($PrivateData.Keys | Where-Object { $_ -ne "PSData" })) {
        $ModulePrivateData[$Key] = $PrivateData[$Key]
    }

    if ($ModulePrivateData.Count) {
        $ManifestArgs.PrivateData = $ModulePrivateData
    }

    # Reset FileList first: Update-ModuleManifest aborts if the current list references a missing file.
    $ManifestContent = Get-Content -Path $ManifestPath -Raw
    $ManifestContent = $ManifestContent -replace "(?s)FileList\s*=.*?(?=\r?\n#\s*Private data)", "FileList = '${ManifestPath}'`n"
    Set-Content -Path $ManifestPath -Value $ManifestContent -NoNewline

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
