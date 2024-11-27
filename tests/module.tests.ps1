using namespace System.IO

param(
    [string] $ModuleName = "Toolbox"
)

$ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
$ProjectRoot = $(Get-Item $([Path]::Combine($ScriptPath, ".."))).FullName

Describe "Run Toolbox Module Unit Tests" {
    $ManifestPath = "${ModuleName}.psd1"

    & $([Path]::Combine($ProjectRoot, "Scripts", "build.ps1"))
    Import-Module -Name $([Path]::Combine($ProjectRoot, "src", $ManifestPath)) `
        -ErrorAction Stop `
        -PassThru

    Context "Test Toolbox" {
        It "Should return a password of the expected length (Get-RandomPassword)" {
            $ExpectedLength = 32
            $Password = Get-RandomPassword -Length $ExpectedLength
            $Password.Length | Should -BeExactly $ExpectedLength
        }
    }
}
