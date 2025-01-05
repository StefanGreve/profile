using namespace System.Security

function Get-Salt {
    <#
        .SYNOPSIS
        Generates a cryptographically secure random byte array to be used as a salt.

        .DESCRIPTION
        Creates a secure random byte array of the specified length using the
        System.Security.Cryptography.RandomNumberGenerator class. Salts are typically
        used in cryptographic operations, such as password hashing, to ensure that
        each operation has a unique input.

        .PARAMETER Length
        Specifies the length of the salt to generate. The default is 32 bytes.

        .INPUTS
        None. You can't pipe objects to Get-Salt.

        .EXAMPLE
        PS> Get-Salt -Length 64

        Generates a 64-byte salt and displays it as an array of bytes.

        .OUTPUTS
        byte[]. A cryptographically secure random byte array of the specified length.

        .LINK
        https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.randomnumbergenerator
    #>
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
