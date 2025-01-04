using namespace System.Security.AccessControl
using namespace System.Security.Cryptography
using namespace System.Security.Cryptography.X509Certificates

function Install-Certificate {
    <#
        .SYNOPSIS
        Installs an X.509 certificate to a specified certificate store location.

        .DESCRIPTION
        Installs an X.509 certificate from a specified file into a specified
        certificate store location.

        .PARAMETER FilePath
        Specifies the path to the certificate file to be installed. This file can
        be in formats such as "*.pfx" or "*.cer".

        .PARAMETER StoreLocation
        Specifies the certificate store location where the certificate will be installed.
        Accepted values are CurrentUser or LocalMachine.

        .PARAMETER Password
        Specifies the password for the certificate file if it is password-protected.

        .PARAMETER User
        Specifies the user context under which the certificate will be installed.
        The default value is the current domain user.

        .INPUTS
        None. You can't pipe objects to Install-Certificate.

        .EXAMPLE
        PS>$Certificate = "./path/to/certificate.pfx"
        PS>$Password = Read-Host -Prompt "Password" -AsSecureString
        PS>Install-Certificate -FilePath $Certificate -StoreLocation LocalMachine -Password $Password

        Installs the certificate.pfx certificate into the LocalMachine certificate
        store using the specified password.

        .OUTPUTS
        X509Certificate. Returns an object representing the installed X.509 certificate.
    #>
    [OutputType([X509Certificate])]
    param(
        [Parameter(Mandatory)]
        [string] $FilePath,

        [Parameter(Mandatory)]
        [StoreLocation] $StoreLocation,

        [SecureString] $Password,

        [string] $User = "$env:USERDOMAIN\$env:USERNAME"
    )

    begin {
        if (!$IsWindows) {
            Write-Error $OperatingSystemNotSupportedError -Category NotImplemented -ErrorAction Stop
        }
    }
    process {
        $Certificate = Import-PfxCertificate -FilePath $FilePath -CertStoreLocation $StoreLocation -Password $Password


        # Beware that the PrivateKey (PK) property returns a different type between .NET Framework and .NET Core.
        $UniqueName = if ($PSVersionTable.PSVersion.Major -eq 5) {
            # PK returns a RSACryptoServiceProvider instance provided by the Cryptographic Service Provider (CSP).
            # This cryptography subsystem was superseded by CNG with the advent of .NET Core.
            $Certificate.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName
        } else {
            # PK returns a RSACng instance provided by the Cryptography Next Generation (CNG), which is not
            # available for operating systems other than Windows. On Linux and MacOS, the PK would be of type
            # RSAOpenSsl. The PrivateKey property was obsoleted for these reasons, and it is now recommended
            # to use the GetRSAPrivateKey extension method which returns an implementation-agnostic abstract
            # base class.
            [RSACertificateExtensions]::GetRSAPrivateKey($Certificate).Key.UniqueName
        }

        # Grant persistent read permissions to the domain user, so that the certificate
        # does not need to be re-installed after a reboot.
        $AclPath = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\$UniqueName"
        $Acl = Get-Acl -Path $AclPath
        $Rule = [FileSystemAccessRule]::new($User, [FileSystemRights]::Read, [AccessControlType]::Allow)
        $Acl.AddAccessRule($Rule)
        Set-Acl -Path $AclPath -AclObject $Acl
    }
    clean {
        Write-Output $Certificate
    }
}
