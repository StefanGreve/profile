using namespace System.Security.AccessControl
using namespace System.Security.Cryptography
using namespace System.Security.Cryptography.X509Certificates

function Install-Certificate {
    [OutputType([X509Certificate])]
    param(
        [Parameter(Mandatory)]
        [string] $FilePath,

        [Parameter(Mandatory)]
        [StoreLocation] $StoreLocation,

        [securestring] $Password,

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
            # PK returns a RSACng instance provided by the Cryptography Next Generation (CNG), which isn't available for
            # operating systems other than Windows. On Linux and MacOS, the PK would be of type RSAOpenSsl. The PrivateKey
            # property was obsoleted for these reasons, and it is now recommended to use the GetRSAPrivateKey extension method
            # which returns an implementation-agnostic abstract base class.
            [RSACertificateExtensions]::GetRSAPrivateKey($Certificate).Key.UniqueName
        }

        # Grant persistent read permissions to the domain user, so that the certificate doesn't need to
        # be re-installed after a reboot.
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
