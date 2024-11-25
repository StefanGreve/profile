using namespace System.Security

function Get-Salt {
    [OutputType([Byte[]])]
    param(
        [int] $Size = 32
    )

    begin {
        $Salt = [byte[]]::new($Size)
    }
    process {
        [Cryptography.RandomNumberGenerator]::Fill($Salt)
        Write-Output $Salt
    }
    clean {
        $Salt.Clear()
    }
}
