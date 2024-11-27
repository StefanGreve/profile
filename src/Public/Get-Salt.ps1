using namespace System.Security

function Get-Salt {
    [OutputType([Byte[]])]
    param(
        [int] $Length = 32
    )

    begin {
        $Salt = [byte[]]::new($Length)
    }
    process {
        [Cryptography.RandomNumberGenerator]::Fill($Salt)
        Write-Output $Salt
    }
    clean {
        $Salt.Clear()
    }
}
