using namespace System.Security.Cryptography

function Get-RandomPassword {
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [ValidateRange(8, 256)]
        [int] $Length = 64
    )

    begin {
        # Base64 encoding encodes every 3 bytes of input data into 4 characters
        # of output data. The required length of the password can be computed by
        $Size = [Math]::Floor($Length * 3 / 4)
        $Buffer = [byte[]]::new($Size)
    }
    process {
        [RandomNumberGenerator]::Fill($Buffer)
        $Password = [Convert]::ToBase64String($Buffer)
    }
    clean {
        Write-Output $Password
    }
}
