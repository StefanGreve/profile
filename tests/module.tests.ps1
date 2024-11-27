using namespace System.IO

param(
    [string] $ModuleName = "Toolbox"
)

$ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
$ProjectRoot = $(Get-Item $([Path]::Combine($ScriptPath, ".."))).FullName

& $([Path]::Combine($ProjectRoot, "Scripts", "build.ps1"))
Import-Module -Name $([Path]::Combine($ProjectRoot, "src", "${ModuleName}.psd1")) `
    -ErrorAction Stop `
    -PassThru

#region Unit Tests

Describe "Get-Definition" {
    Context "Happy Path" {
        It "Should return a definition" {
            $Definition = Get-Definition Get-Content
            $Definition.Length | Should -Not -Be 0 -Because "this command exists"
        }
    }

    Context "Negative Testing" {
        It "Should return an error if the argument is invalid" {
            { Get-Definition Get-Nothing } | Should -Throw -Because "this command does not exist"
        }
    }
}

Describe "Get-RandomPassword" {
    Context "Happy Path" {
        It "Should return a password of the specified length" {
            $ExpectedLength = 32
            $Password = Get-RandomPassword -Length $ExpectedLength
            $Password.Length | Should -Be $ExpectedLength
        }
    }
}

Describe "Get-Salt" {
    Context "Happy Path" {
        It "Should return an array of the specified length" {
            $ExpectedLength = 10
            $Salt = Get-Salt -Length $ExpectedLength
            $Salt.Length | Should -Be $ExpectedLength -Because "that is was the input specified"
        }
    }
}

Describe "Test-Command" {
    Context "Happy Path" {
        It "Should return true if the command exists" {
            $Exists = Test-Command Get-Content
            $Exists | Should -Be $true -Because "this command exists"
        }
    }

    Context "Negative Testing" {
        It "Should return false if the command does not exist" {
            $Exists = Test-Command Get-Nothing
            $Exists | Should -Be $false -Because "this command does not exist"
        }
    }
}

#endregion
