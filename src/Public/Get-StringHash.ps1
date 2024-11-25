using namespace System.Security
using namespace System.Text

function Get-StringHash {
    [OutputType([string])]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [string[]] $String,

        [Parameter(Position = 1)]
        [Cryptography.HashAlgorithmName] $Algorithm = [Cryptography.HashAlgorithmName]::SHA256
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
                Default {
                    Write-Error "Hash Algorithm is not implemented" -Category InvalidArgument -ErrorAction Stop
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
