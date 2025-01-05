using namespace System.Security
using namespace System.Text

function Get-StringHash {
    <#
        .SYNOPSIS
        Computes the cryptographic hash of input strings using the specified algorithm.

        .DESCRIPTION
        Computes a hash for each input string using a cryptographic hash algorithm
        (e.g., MD5, SHA1, SHA256, SHA384, or SHA512). The hash is returned as a
        lowercase hexadecimal string.

        By default, the function uses the SHA256 algorithm. Input strings are processed
        as UTF-8 encoded byte arrays before computing the hash.

        Use SHA256 or higher for secure hashing in modern applications.
        MD5 and SHA1 are considered insecure for cryptographic purposes.

        .PARAMETER String
        Specifies the input strings to hash. Accepts pipeline input for multiple strings.

        .PARAMETER Algorithm
        Specifies the cryptographic hash algorithm to use. Defaults to SHA256.

        .INPUTS
        System.String[]. Strings to hash. Can be passed via pipeline.

        .EXAMPLE
        PS> Get-StringHash -String "Hello, World!"

        Computes the SHA256 hash of the string "Hello, World!".

        .EXAMPLE
        PS> "password" | Get-StringHash -Algorithm MD5

        Computes the MD5 hash of the string "password" from pipeline input.

        .OUTPUTS
        System.String. The computed hash as a lowercase hexadecimal string.

        .LINK
        https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography
    #>
    [OutputType([string])]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [string[]] $String,

        [Parameter(Position = 1)]
        [ValidateSet("MD5", "SHA1", "SHA256", "SHA384", "SHA512")]
        $Algorithm = "SHA256"
    )

    process {
        foreach ($s in $String) {
            $Constructor = switch ($Algorithm) {
                MD5 {
                    [Cryptography.MD5]::Create()
                }
                SHA1 {
                    [Cryptography.SHA1]::Create()
                }
                SHA256 {
                    [Cryptography.SHA256]::Create()
                }
                SHA384 {
                    [Cryptography.SHA384]::Create()
                }
                SHA512 {
                    [Cryptography.SHA512]::Create()
                }
            }

            $Buffer = $Constructor.ComputeHash([Encoding]::UTF8.GetBytes($s))
            $Hash = [BitConverter]::ToString($Buffer).Replace("-", [string]::Empty).ToLower()
            Write-Output $Hash
        }
    }
    clean {
        $Constructor.Dispose()
    }
}
