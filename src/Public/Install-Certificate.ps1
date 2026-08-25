using namespace System.IO
using namespace System.Security.AccessControl
using namespace System.Security.Cryptography
using namespace System.Security.Cryptography.X509Certificates

function Install-Certificate {
    <#
        .SYNOPSIS
        Imports a certificate into the Windows certificate store.

        .DESCRIPTION
        Installs an X.509 certificate from a specified file into a specified
        certificate store location, and grants persistent read permissions on the
        private key to the specified user, so that the key remains accessible
        after a reboot.

        .PARAMETER FilePath
        Path to the certificate file to import. Supports .pfx and PEM-encoded formats
        such as .crt.

        .PARAMETER PrivateKeyPath
        Path to a PEM-encoded private key file to associate with the certificate.
        Only applicable for PEM certificates; ignored for .pfx files.

        .PARAMETER StoreLocation
        Specifies the certificate store location where the certificate will be installed.
        Accepted values are defined here:
        https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storelocation

        .PARAMETER StoreName
        Specifies the name of the X.509 certificate store to open.
        Accepted values are defined here:
        https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storename

        .PARAMETER Password
        Password used to decrypt the certificate or private key file, if encrypted.

        .PARAMETER User
        Specifies the user context under which the certificate will be installed.
        The default value is the current domain user.

        .INPUTS
        System.String. You can pipe a certificate file path to Install-Certificate, including file
        objects from Get-ChildItem (bound by their FullName property).

        .OUTPUTS
        X509Certificate2. Returns an object representing the installed X.509 certificate.

        .EXAMPLE
        PS>$Certificate = "./path/to/certificate.pfx"
        PS>$Password = Read-Host -Prompt "Password" -AsSecureString
        PS>Install-Certificate -FilePath $Certificate -StoreLocation LocalMachine -StoreName My -Password $Password

        Installs the certificate.pfx certificate into the Personal (My) store of the
        LocalMachine location using the specified password.
    #>
    [OutputType([X509Certificate2])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("FullName", "PSPath")]
        [string] $FilePath,

        [Parameter(Mandatory)]
        [StoreLocation] $StoreLocation,

        [Parameter()]
        [string] $PrivateKeyPath,

        [Parameter(Mandatory)]
        [StoreName] $StoreName,

        [SecureString] $Password,

        [string] $User = "$env:USERDOMAIN\$env:USERNAME"
    )
    begin {
        if (!$IsWindows) {
            Write-Error "This Cmdlet only works on the Windows Operating System" `
                -Category NotImplemented `
                -ErrorAction Stop
        }
    }
    process {
        # Computed per item so -FilePath can be bound from the pipeline.
        $IsPfx = [Path]::GetExtension($FilePath) -ieq ".pfx"

        $Arguments = @{
            CertStoreLocation = "Cert:\$StoreLocation\$StoreName"
            FilePath = $FilePath
        }

        if ($null -ne $Password) {
            $Arguments.Add("Password", $Password)
        }

        $Certificate = if ($IsPfx) {
            Import-PfxCertificate @Arguments
        } else {
            $CertificateStore = [X509Store]::new($StoreName, $StoreLocation)

            try {
                $HasPassword = $null -ne $Password
                $CertificateStore.Open([OpenFlags]::ReadWrite)

                $PemCertificate = if($HasPassword) {
                    [X509Certificate2]::new($FilePath, $Password, [X509KeyStorageFlags]::DefaultKeySet)
                } else {
                    [X509Certificate2]::new($FilePath)
                }

                if (![string]::IsNullOrEmpty($PrivateKeyPath)) {
                    $PemContent = [File]::ReadAllText($PrivateKeyPath)
                    $PrivateKey = [RSA]::Create()

                    if ($HasPassword) {
                        # NOTE: ImportFromEncryptedPem does not implement an overload for SecureString
                        $PlaintextPassword = ConvertFrom-SecureString -SecureString $Password -AsPlainText
                        $PrivateKey.ImportFromEncryptedPem($PemContent, $PlaintextPassword)
                    } else {
                        $PrivateKey.ImportFromPem($PemContent)
                    }

                    $PemCertificate = [RSACertificateExtensions]::CopyWithPrivateKey($PemCertificate, $PrivateKey)
                    $PrivateKey.Dispose()

                    # RSA.Create() produces an ephemeral key with no CNG key container. Re-importing via PFX round-trip
                    # forces Windows to persist the key in the machine key store, giving it a UniqueName for ACL assignment.
                    $Exported = $PemCertificate.Export([X509ContentType]::Pfx)
                    $PemCertificate = [X509Certificate2]::new($Exported, $null, [X509KeyStorageFlags]::MachineKeySet -bor [X509KeyStorageFlags]::PersistKeySet)
                    Write-Verbose "Retrieved certificate with thumbprint '$($PemCertificate.Thumbprint)'."
                }

                $CertificateStore.Add($PemCertificate)
            }
            catch [ArgumentException], [CryptographicException] {
                Write-Error "Failed to load certificate '$FilePath' to the certificate store: $_" `
                    -Category InvalidData `
                    -ErrorAction Stop
            }
            finally {
                $CertificateStore.Close()
                $CertificateStore.Dispose()
            }

            # If no private key is provided, the certificate will only contain the public key.
            Write-Output $PemCertificate
        }

        # Use the GetRSAPrivateKey extension method, which returns an implementation-agnostic abstract base class.
        # On Windows the private key is backed by an RSACng instance (Cryptography Next Generation); the legacy
        # PrivateKey property is avoided because it returns platform-specific types (RSAOpenSsl on Linux/macOS).
        $PrivateKey = [RSACertificateExtensions]::GetRSAPrivateKey($Certificate)

        if ($null -eq $PrivateKey) {
            Write-Error "The certificate '$FilePath' has no private key." `
                -Category ObjectNotFound `
                -ErrorAction Stop
        }

        $UniqueName = $PrivateKey.Key.UniqueName
        Write-Verbose "Detected Unique Name '$UniqueName'."

        $AclPath = if ($IsPfx) {
            "$env:ProgramData\Microsoft\Crypto\RSA\MachineKeys\$UniqueName"
        } else {
            "$env:ProgramData\Microsoft\Crypto\Keys\$UniqueName"
        }

        # Grant persistent read permissions to the domain user, so that the certificate doesn't need to
        # be re-installed after a reboot.
        $Acl = Get-Acl -Path $AclPath
        $Rule = [FileSystemAccessRule]::new($User, [FileSystemRights]::Read, [AccessControlType]::Allow)
        $Acl.AddAccessRule($Rule)
        Set-Acl -Path $AclPath -AclObject $Acl

        Write-Output $Certificate
    }
}
