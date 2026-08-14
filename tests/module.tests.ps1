using namespace System.IO

param(
    [string] $ModuleName = "PowerTools",

    [string] $Version,

    [switch] $Build
)

$ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
$ProjectRoot = $(Get-Item $([Path]::Combine($ScriptPath, ".."))).FullName

if ($Build.IsPresent) {
    & $([Path]::Combine($ProjectRoot, "scripts", "build.ps1")) -Version $Version
}

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

Describe "Get-StringHash" {
    Context "Happy Path" {
        It "Should compute the correct MD5 hash" {
            # Well-known vector: MD5("password")
            Get-StringHash -String "password" -Algorithm MD5 | Should -Be "5f4dcc3b5aa765d61d8327deb882cf99"
        }

        It "Should compute the correct SHA1 hash" {
            # Well-known vector: SHA1("password")
            Get-StringHash -String "password" -Algorithm SHA1 | Should -Be "5baa61e4c9b93f3f0682250b6cf8331b7ee68fd8"
        }

        It "Should compute the correct SHA256 hash by default" {
            # Well-known vector: SHA256("Hello, World!")
            $Expected = "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f"
            Get-StringHash -String "Hello, World!" | Should -Be $Expected
        }

        It "Should return a lowercase hexadecimal string" {
            Get-StringHash -String "Hello, World!" | Should -MatchExactly "^[0-9a-f]+$"
        }

        It "Should accept pipeline input" {
            "password" | Get-StringHash -Algorithm MD5 | Should -Be "5f4dcc3b5aa765d61d8327deb882cf99"
        }
    }
}

Describe "Get-FileSize" {
    BeforeAll {
        # A file of exactly 1 KiB (1024 bytes) makes the base-2 conversions exact.
        $File = Join-Path $TestDrive "sample.bin"
        [System.IO.File]::WriteAllBytes($File, [byte[]]::new(1024))
    }

    Context "Happy Path" {
        It "Should return the size in bytes by default" {
            Get-FileSize -Path $File | Should -Be 1024
        }

        It "Should convert the size to KiB" {
            Get-FileSize -Path $File -Unit KiB | Should -Be 1
        }
    }

    Context "Negative Testing" {
        It "Should skip directories and emit a non-terminating error" {
            $Result = Get-FileSize -Path $TestDrive -ErrorVariable FileSizeError 2>$null
            $Result | Should -BeNullOrEmpty -Because "a directory is not a file"
            $FileSizeError | Should -Not -BeNullOrEmpty -Because "a directory path is invalid input"
        }
    }
}

Describe "Get-FileCount" {
    BeforeAll {
        $Root = Join-Path $TestDrive "count"
        New-Item -ItemType Directory -Path $Root | Out-Null
        1..3 | ForEach-Object { New-Item -ItemType File -Path (Join-Path $Root "file$_.txt") | Out-Null }

        $SubDirectory = Join-Path $Root "nested"
        New-Item -ItemType Directory -Path $SubDirectory | Out-Null
        New-Item -ItemType File -Path (Join-Path $SubDirectory "deep.txt") | Out-Null
    }

    Context "Happy Path" {
        It "Should count files in all subdirectories by default" {
            Get-FileCount -Path $Root | Should -Be 4 -Because "there are three top-level files and one nested file"
        }

        It "Should count only top-level files when requested" {
            Get-FileCount -Path $Root -SearchOption TopDirectoryOnly | Should -Be 3 -Because "the nested file is excluded"
        }
    }
}

#endregion
