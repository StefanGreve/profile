using namespace System
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Diagnostics
using namespace System.Globalization
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Net.Http
using namespace System.Runtime
using namespace System.Security
using namespace System.Security.AccessControl
using namespace System.Security.Cryptography.X509Certificates
using namespace System.Text
using namespace System.Threading

using namespace Microsoft.PowerShell

#region configurations

$global:ProfileVersion = [PSCustomObject]@{
    Major = 1
    Minor = 7
    Patch = 0
}

$global:OperatingSystem = if ([OperatingSystem]::IsWindows()) {
    [OS]::Windows
} elseif ([OperatingSystem]::IsLinux()) {
    [OS]::Linux
} elseif ([OperatingSystem]::IsMacOS()) {
    [OS]::MacOS
} else {
    [OS]::Unknown
}

[CultureInfo]::CurrentCulture = "ja-JP"
$PSDefaultParameterValues["*:Encoding"] = "utf8"

if ($env:PROFILE_LOAD_CUSTOM_SCRIPTS) {
    Get-ChildItem -Path $env:PROFILE_LOAD_CUSTOM_SCRIPTS -Filter "*.ps1" | ForEach-Object {
        . $_.FullName
    }
}

if ([OperatingSystem]::IsWindows()) {
    $global:PSRC = "$HOME\Documents\PowerShell\profile.ps1"
    $global:IsAdmin = ([Principal.WindowsPrincipal][Principal.WindowsIdentity]::GetCurrent()).IsInRole([Principal.WindowsBuiltInRole]::Administrator)
}

if ([OperatingSystem]::IsLinux()) {
    $global:IsAdmin = $(id -u) -eq 0
}

$global:Natural = { [Regex]::Replace($_.Name, '\d+', { $Args[0].Value.PadLeft(20) }) }

$PSStyle.Progress.View = "Classic"
$Host.PrivateData.ProgressBackgroundColor = "Cyan"
$Host.PrivateData.ProgressForegroundColor = "Yellow"
$ErrorView = "ConciseView"

$PSReadLineOptions = @{
    PredictionSource = "HistoryAndPlugin"
    PredictionViewStyle = "ListView"
    HistoryNoDuplicates = $true
    HistorySearchCursorMovesToEnd = $true
    ShowTooltips = $true
    EditMode = "Windows"
    BellStyle = "None"
}
Set-PSReadLineOption @PSReadLineOptions

Set-PSReadLineKeyHandler -Key Tab -Function Complete
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Ctrl+u -Function RevertLine
Set-PSReadLineKeyHandler -Key Ctrl+s -BriefDescription SaveInHistory -LongDescription "Save current line in history without execution" -ScriptBlock {
    param($Key, $Arg)

    $Line = $null
    $Cursor = $null

    [PSConsoleReadLine]::GetBufferState([ref]$Line, [ref]$Cursor)
    [PSConsoleReadLine]::AddToHistory($Line)
    [PSConsoleReadLine]::RevertLine()
}
Set-PSReadLineKeyHandler -Key '(', '[', '{' -BriefDescription InsertPairedBraces -LongDescription "Insert matching braces" -ScriptBlock {
    param($Key, $Arg)

    $CloseChar = switch ($Key.KeyChar) {
        <#case#> '(' { [char]')'; break }
        <#case#> '[' { [char]']'; break }
        <#case#> '{' { [char]'}'; break }
    }

    $SelectionStart = $null
    $SelectionLength = $null
    [PSConsoleReadLine]::GetSelectionState([ref]$SelectionStart, [ref]$SelectionLength)

    $Line = $null
    $Cursor = $null
    [PSConsoleReadLine]::GetBufferState([ref]$Line, [ref]$Cursor)

    if ($SelectionStart -ne -1) {
        [PSConsoleReadLine]::Replace($SelectionStart, $SelectionLength, $Key.KeyChar + $Line.SubString($SelectionStart, $SelectionLength) + $CloseChar)
        [PSConsoleReadLine]::SetCursorPosition($SelectionStart + $SelectionLength + 2)
    }
    else {
        [PSConsoleReadLine]::Insert("$($Key.KeyChar)$CloseChar")
        [PSConsoleReadLine]::SetCursorPosition($Cursor + 1)
    }
}
Set-PSReadLineKeyHandler -Key ')', ']', '}' -BriefDescription SmartClosingBraces -LongDescription "Insert closing brace or skip" -ScriptBlock {
    param($Key, $Arg)

    $Line = $null
    $Cursor = $null
    [PSConsoleReadLine]::GetBufferState([ref]$Line, [ref]$Cursor)

    if ($Line[$Cursor] -and $Key.KeyChar) {
        [PSConsoleReadLine]::SetCursorPosition($Cursor + 1)
    }
    else {
        [PSConsoleReadLine]::Insert("$($Key.KeyChar)")
    }
}

#endregion configurations

#regions enums

enum OS
{
    Unknown = 0
    Windows = 1
    Linux = 2
    MacOS = 3
}

enum Month
{
    January = 1
    Febraury = 2
    March = 3
    April = 4
    May = 5
    June = 6
    July = 7
    August = 8
    September = 9
    October = 10
    November = 11
    December = 12
}

#endregion

#region functions

function Test-Command {
    [OutputType([bool])]
    param(
        [string] $Name
    )

    process {
        $PrevPreference = $ErrorActionPreference

        try {
            $ErrorActionPreference = "stop"
            Get-Command $Name | Out-Null
            return $true
        }
        catch {
            return $false
        }
        finally {
            $ErrorActionPreference = $PrevPreference
        }
    }
}

function Set-WindowsTheme {
    [OutputType([void])]
    param(
        [ValidateSet("Light", "Dark")]
        [string] $Theme
    )

    process {
        if ($global:OperatingSystem -ne [OS]::Windows) {
            Write-Error "This Cmdlet only works on the Windows Operating System" -ErrorAction Stop
        }

        $Personalize = "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        $RegistryPath = Get-ItemProperty -Path "Registry::$Personalize"
        $RegistryPath | Set-ItemProperty -Name "AppsUseLightTheme" -Value ([int]($Theme -eq "Light"))
    }
}

function Set-MonitorBrightness {
    [OutputType([void])]
    param(
        [ValidateRange(0, 100)]
        [int] $Brightness
    )
    begin {
        if ($global:OperatingSystem -ne [OS]::Windows) {
            Write-Error "This Cmdlet only works on the Windows Operating System" -ErrorAction Stop
        }

        $Timeout = 1 # in seconds
        $WmiMonitor = Get-CimInstance -Namespace root/WMI -Class WmiMonitorBrightnessMethods
    }
    process {
        try {
            $WmiMonitor.WmiSetBrightness($Timeout, $Brightness)
        }
        catch {
            $Message = "This computer doesn't appear to suport brightness adjustments through software. Updating your display adapter drivers may help to resolve this issue."
            Write-Error $Message -ErrorAction Stop -Category DeviceError
        }
    }
    clean {
        $WmiMonitor.Dispose()
    }
}

function Export-Icon {
    [OutputType([void])]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Low")]
    param(
        [Parameter(Mandatory, HelpMessage = "Path to SVG file")]
        [string] $Path,

        [Parameter()]
        [string] $Destination = $PWD,

        [Parameter()]
        [int] $MinSize = 16,

        [Parameter()]
        [int] $MaxSize = 1024,

        [Parameter()]
        [switch] $Compress
    )

    begin {
        $File = Get-Item -Path $Path

        if ($File.Extension -ne ".svg") {
            Write-Error -Message "Not a SVG file" -Category InvalidArgument -ErrorAction Stop
        }

        $BaseName = $File.BaseName
    }
    process {
        if ($PSCmdlet.ShouldProcess($File.Name)) {
            $Directory = [Directory]::CreateDirectory([Path]::Combine($Destination, $BaseName))

            while ($MaxSize -ge $MinSize) {
                $FullName = Join-Path -Path $Destination -ChildPath "${MaxSize}x$MaxSize-$BaseName.png" -Resolve
                Write-Verbose "Exporting $Fullname . . ."
                inkscape $Path -w $MaxSize -h $MaxSize -o $FullName
                $MaxSize /= 2

                Move-Item -Path $FullName -Destination $Directory
            }
        }
    }
    end {
        if (!$Compress.IsPresent) { return }
        Write-Verbose "Compressing $Directory . . ."

        Get-ChildItem -Path $Directory | ForEach-Object {
            Compress-Archive -Path $_ -DestinationPath $Directory -CompressionLevel Optimal -Update
        }

        Remove-Item -Path $Directory -Recurse
    }
}

function Get-StringHash {
    [OutputType([string])]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [string[]] $String,

        [Parameter()]
        [Cryptography.HashAlgorithmName] $Algorithm = [Cryptography.HashAlgorithmName]::SHA256
    )

    process {
        foreach ($s in $String) {
            $Constructor = switch ($Algorithm) {
                MD5 { [Cryptography.MD5]::Create() }
                SHA1 { [Cryptography.SHA1]::Create() }
                SHA256 { [Cryptography.SHA256]::Create() }
                SHA384 { [Cryptography.SHA384]::Create() }
                SHA512 { [Cryptography.SHA512]::Create() }
                Default { Write-Error "Hash Algorithm is not implemented" -Category InvalidArgument -ErrorAction Stop }
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

function Get-FileSize {
    [OutputType([double])]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [string[]] $Path,

        [Parameter()]
        [ValidateSet("B", "KiB", "MiB", "GiB", "TiB", "PiB")]
        [string] $Unit = "B"
    )

    process {
        foreach ($p in $Path) {
            $Bytes = [Math]::Abs($(Get-Item $p).Length)

            $Size = switch ($Unit) {
                "PiB" { $Bytes / 1PB }
                "TiB" { $Bytes / 1TB }
                "GiB" { $Bytes / 1GB }
                "MiB" { $Bytes / 1MB }
                "KiB" { $Bytes / 1KB }
                Default { $Bytes }
            }

            Write-Output $Size
        }
    }
}

function Get-FileCount {
    [Alias("count")]
    [OutputType([int])]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [string[]] $Path,

        [SearchOption] $SearchOption = [SearchOption]::AllDirectories
    )

    process {
        foreach ($p in $Path) {
            $FileCount = [Directory]::GetFiles([Path]::Combine($PWD, $p), "*", $SearchOption).Length
            Write-Output $FileCount
        }
    }
}

function Copy-FilePath {
    [Alias("copy")]
    [OutputType([void])]
    param (
        [Parameter(Position = 0, Mandatory)]
        [string] $Path
    )

    process {
        $FullName = $(Get-Item $Path).FullName
        Set-Clipboard -Value $FullName
    }
}

function Get-MaxPathLength {
    process {
        switch ($global:OperatingSystem) {
            ([OS]::Windows) {
                # On Windows, file names cannot exceed 256 bytes. Starting with Windows 10 (version 1607), the max path
                # limit preference can be configured in the registry (which is a opt-in feature):
                # Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Type DWord -Value 1 -Force
                # https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation
                $FileSystem = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled"
                $MaxPathLength = $FileSystem.LongPathsEnabled -eq 1 ? 32767 : 260
                Write-Output $MaxPathLength
             }
            ([OS]::Linux) {
                # On virtually all file systems, file names are restricted to 255 bytes in length (cf. NAME_MAX).
                # PATH_MAX equals 4096 bytes in Unix environments, though Unix can deal with longer file paths by using
                # relative paths or symbolic links. To convert bytes to characters, you need to know the encoding ahead
                # of time. For example, an ASCII or Unicode character in UTF-8 is 8 bits (1 byte), while a Unicode character
                # in UTF-16 may take between 16 bits (2 bytes) and 32 bits (4 bytes) in memory, whereas UTF-32 encoded
                # Unicode characters always require 32 bits (4 bytes) of memory
                $MaxPathLength = getconf PATH_MAX /
                Write-Output $MaxPathLength
            }
        }
    }
}

function New-Shortcut {
    [CmdletBinding()]
    [OutputType([FileSystemInfo])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Target,

        [string] $Description
    )

    begin {
        if ($global:OperatingSystem -ne [OS]::Windows) {
            Write-Error "This Cmdlet only works on the Windows Operating System" -ErrorAction Stop
        }

        $Shell = New-Object -ComObject WScript.Shell
    }
    process {
        $Directory = Resolve-Path $Path
        $Name = [Path]::ChangeExtension([Path]::Combine($Directory, $Name), ".lnk")

        if ([File]::Exists($Name)) {
            Write-Error -Message "The file '$Name' already exists" -Category ResourceExists -CategoryTargetName $Name -ErrorAction Stop
        }

        $Shortcut = $Shell.CreateShortcut($Name)
        $Shortcut.TargetPath = $Target
        $Shortcut.Description = $Description
        $Shortcut.Save()
        Get-Item -Path $Name

    }
    clean {
        [InteropServices.Marshal]::ReleaseComObject($Shell) | Out-Null
    }
}

class Battery
{
    [int] $ChargeRemaining
    [timespan] $Runtime
    [bool] $IsCharging
    [string] $Status

    Battery([int] $ChargeRemaining, [timespan] $Runtime, [bool] $IsCharging, [string] $Status)
    {
        $this.ChargeRemaining = $ChargeRemaining
        $this.Runtime = $Runtime
        $this.IsCharging = $IsCharging
        $this.Status = $Status
    }

    [string] ToString()
    {
        $Color = $White = $global:PSStyle.Foreground.White

        switch ($this.ChargeRemaining) {
            { $_ -ge 70 -and $_ -le 100 } { $Color = $global:PSStyle.Foreground.Green }
            { $_ -ge 30 -and $_ -le 69 } { $Color = $global:PSStyle.Foreground.Yellow }
            { $_ -ge 1 -and $_ -le 29 } { $Color = $global:PSStyle.Foreground.Red }
        }

        $MinutesLeft = [string]::Format("Estimated Runtime: {0}", $this.Runtime.ToString())

        return [string]::Format("Capacity: {1}{3}%{0} ({2}{4}{0}) - {5}",
            $White,
            $Color,
            $global:PSStyle.Foreground.Yellow,
            $this.ChargeRemaining,
            $this.Status,
            $MinutesLeft
        )
    }
}

function Get-Battery {
    [Alias("battery")]
    [OutputType([Battery])]
    param()

    Write-Output $(switch ($global:OperatingSystem) {
        ([OS]::Windows) {
            $Win32Battery = Get-CimInstance -ClassName Win32_Battery
            $ChargeRemaining = $Win32Battery.EstimatedChargeRemaining
            # An unhandled 32-bit integer overflow is the reason why Win32_Battery
            # sometimes reports (2^32)/60 as the estimated runtime. This property
            # will only yield an estimate if the utility power is off, is lost and
            # remains off, or if a laptop is disconnected from a power source.
            $Minutes = $Win32Battery.EstimatedRunTime ?? 0
            $IsCharging = $Minutes -eq 0x04444444 -or ($Win32Battery.BatteryStatus -ge 6 -and $Win32Battery.BatteryStatus -le 9)
            $Runtime = New-TimeSpan -Minutes $($IsCharging ? 0 : $Minutes)

            # The first two statuses were renamed to reduce ambiguity.
            # The second status indicates whether a device has access to AC, which
            # means that no battery is being discharged. However, the battery is
            # not necessarily charging, either.
            $Status = switch ($Win32Battery.BatteryStatus) {
                1 { "Discharging" } # Other
                2 { "Connected to AC" } # Unknown
                3 { "Fully Charged" }
                4 { "Low" }
                5 { "Critical" }
                6 { "Charging" }
                7 { "Charging and High" }
                8 { "Charging and Low" }
                9 { "Charging and Critical" }
                10 { "Undefined" }
                11 { "Partially Charged" }
                Default { "Unknown" }
            }

            [Battery]::new($ChargeRemaining, $Runtime, $IsCharging, $Status)
            $Win32Battery.Dispose()
        }
        ([OS]::Linux) {
            # TODO
        }
        ([OS]::MacOS) {
            # TODO
        }
    })
}

function Get-Calendar {
    [Alias("cal")]
    [CmdletBinding(DefaultParameterSetName = "Year")]
    param (
        [Parameter(ParameterSetName = "Month")]
        [Month] $Month,

        [Parameter(ParameterSetName = "Year")]
        [Parameter(ParameterSetName = "Month")]
        [ValidateRange(0, 9999)]
        [int] $Year = [datetime]::Now.Year
    )

    process {
        switch ($PSCmdlet.ParameterSetName) {
            "Month" {
                python -c "import calendar; print(calendar.month($Year, $($Month.value__)))"
            }
            "Year" {
                python -c "import calendar; print(calendar.calendar($Year))"
            }
        }
    }
}

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
        [Cryptography.RandomNumberGenerator]::Fill($Buffer)
        $Password = [Convert]::ToBase64String($Buffer)
    }
    end {
        Write-Output $Password
    }
}

function Stop-LocalServer {
    [OutputType([void])]
    [CmdletBinding(ConfirmImpact = 'High', SupportsShouldProcess)]
    param (
        [int] $Port
    )

    process {
        $TcpConnection = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue

        if ($null -eq $TcpConnection) {
            Write-Error "No owning process found listening on Port $Port"
            return
        }

        $Process = Get-Process -Id $TcpConnection.OwningProcess

        if ($PSCmdlet.ShouldProcess("Stop Process", "Are you sure that you want to stop this process with force?", "Stopping Process with ID=$($Process.Id) (Process Name: $($Process.ProcessName))")) {
            Stop-Process $Process -Force
        }
    }
}

function Install-Certificate {
    [OutputType([X509Certificate])]
    param(
        [Parameter(Mandatory)]
        [string] $FilePath,

        [string] $StoreLocation = "Cert:\LocalMachine\My",

        [securestring] $Password,

        [string] $User = "$env:USERDOMAIN\$env:USERNAME"
    )

    begin {
        if ($global:OperatingSystem -ne [OS]::Windows) {
            Write-Error "This Cmdlet only works on the Windows Operating System" -ErrorAction Stop
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
    end {
        Write-Output $Certificate
    }
}

function Get-WorldClock {
    $TimeZoneIds = @(
        "Mountain Standard Time",
        "Paraguay Standard Time",
        "W. Europe Standard Time",
        "Russian Standard Time",
        "Tokyo Standard Time"
    )

    $WorldClock = foreach ($TimeZoneId in $TimeZoneIds) {
        $TimeZoneInfo = [TimeZoneInfo]::FindSystemTimeZoneById($TimeZoneId)

        Write-Output $([PSCustomObject]@{
            Offset = $TimeZoneInfo.GetUtcOffset([DateTimeKind]::Local).Hours
            Date   = [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::Now.ToUniversalTime(), $TimeZoneInfo)
            Name   = $TimeZoneInfo.StandardName
        })
    }

    Write-Output $WorldClock
}

class XKCD {
    [int] $Id
    [string] $Title
    [string] $Alt
    [string] $Img
    [datetime] $Date
    [string] $Path
    hidden [HttpClient] $Client

    [void] Download([bool] $Force = $false) {
        [HttpResponseMessage] $Response = $this.Client.GetAsync($this.Img).GetAwaiter().GetResult()
        $Response.EnsureSuccessStatusCode()
        $ReponseStream = $Response.Content.ReadAsStream()

        if ([File]::Exists($this.Path) -and $Force) {
            Write-Warning -Message "$($this.Path) already exists, deleting file"
            [File]::Delete($this.Path)
        }

        $FileStream = [FileStream]::new($this.Path, [FileMode]::Create)
        $ReponseStream.CopyTo($FileStream)
        $FileStream.Close()
    }

    XKCD([int] $Id, [string] $Path, [HttpClient] $Client) {
        $this.Client = $Client
        $Response = ConvertFrom-Json $this.Client.GetStringAsync("https://xkcd.com/$Id/info.0.json").GetAwaiter().GetResult()

        $this.Id = $Response.Num
        $this.Title = $Response.Title
        $this.Alt = $Response.Alt
        $this.Img = $Response.Img
        $this.Date = [DateTime]::new($Response.Year, $Response.Month, $Response.Day)
        $this.Path = [Path]::Combine($Path, "$($Response.Num).$($this.Img.Split("/")[-1].Split(".")[1])")
    }
}

function Get-XKCD {
    <#
        .SYNOPSIS
        The Get-XKCD cmdlet gets and/or downloads the details of one or more comics from the XKCD API.

        .DESCRIPTION
        The Get-XKCD cmdlet gets and/or downloads the details of one or more comics from the XKCD API. This includes the
        properties Id, Title, Alt, Img, Date and Path.

        .PARAMETER Number
        Define an array of XKCD IDs.

        .PARAMETER All
        Target all XKCD IDs

        .PARAMETER Random
        Use a random XKCD ID.

        .PARAMETER Last
        Target the last `n` XKCD IDs.

        .PARAMETER NoDownload
        Return an XKCD object with meta data, but don't download anything.

        .PARAMETER Path
        Download destination. Defaults to the current working directory.

        .PARAMETER Force
        Delete a file if it already exists, then download it again.

        .EXAMPLE
        PS > xkcd -Last 1 -Verbose | Invoke-Item

        Download the latest XKCD and open the file with the default image application.

        .EXAMPLE
        PS > Get-XKCD -Last 10 -NoDownload | foreach { Write-Output $_.Title }

        Get the last ten titles without downloading any images.

        .EXAMPLE
        PS > Get-XKCD -All -Path $HOME\Desktop\XKCD -Verbose

        Download all known XKCDs and store these images in a specific folder.

        .LINK
        https://xkcd.com

        .LINK
        https://xkcd.com/json.html
    #>
    [Alias("xkcd")]
    [OutputType([XKCD])]
    [CmdletBinding(DefaultParameterSetName = "Last", SupportsShouldProcess, ConfirmImpact = "Low")]
    param(
        [Parameter(Mandatory, ParameterSetName = "Number", Position = 0, ValueFromPipeline)]
        [int[]] $Number,

        [Parameter(Mandatory, ParameterSetName = "All")]
        [switch] $All,

        [Parameter(Mandatory, ParameterSetName = "Random")]
        [switch] $Random,

        [Parameter(ParameterSetName = "Last")]
        [int] $Last = 1,

        [Parameter()]
        [switch] $NoDownload,

        [Parameter()]
        [string] $Path = $PWD.Path,

        [Parameter()]
        [switch] $Force
    )

    begin {
        $Client = [HttpClient]::new()
        [void] $Client.DefaultRequestHeaders.UserAgent.TryParseAdd("${env:USERNAME}@profile.ps1")
        [void] $Client.DefaultRequestHeaders.Accept.Add([Headers.MediaTypeWithQualityHeaderValue]::new("application/json"))

        $Info = if (!$MyInvocation.BoundParameters.ContainsKey("Number") -or $null -eq $Number) {
            ConvertFrom-Json $Client.GetStringAsync("https://xkcd.com/info.0.json").GetAwaiter().GetResult()
        }
    }
    process {
        $Ids = switch ($PSCmdlet.ParameterSetName) {
            "Number" {
                $Number
            }
            "All" {
                1..$Info.Num
            }
            "Random" {
                @([Random]::new().Next(1, $Info.Num))
            }
            default {
                ($Info.Num - $Last + 1)..$Info.Num
            }
        }

        for ([int] $i = 1; $i -le $Ids.Count; $i++) {
            $Id = $Ids[$i - 1]
            $XKCD = [XKCD]::new($Id, $Path, $Client)

            if (!$NoDownload.IsPresent -and $PSCmdlet.ShouldProcess($XKCD.Img, "Download $($XKCD.Path)")) {
                [int] $PercentComplete = [Math]::Round($i / $Ids.Count * 100, 0)
                Write-Progress -Activity "Download XKCD $Id" -Status "$PercentComplete%" -PercentComplete $PercentComplete
                $XKCD.Download($Force.IsPresent)
            }

            Write-Output $XKCD
        }
    }
}

function Restart-GpgAgent {
    gpgconf --kill gpg-agent
    gpgconf --launch gpg-agent
}

function Set-PowerState {
    [OutputType([void])]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param(
        [ValidateSet("Hibernate", "Suspend")]
        [Parameter(Position = 0)]
        [string] $PowerState = "Suspend",

        [Parameter(ParameterSetName = "Windows")]
        [switch] $DisableWake,

        [switch] $Force
    )

    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, $PowerState)) {
        switch ($global:OperatingSystem) {
            ([OS]::Windows) {
                Add-Type -AssemblyName System.Windows.Forms
                $PowerState = $PowerState -eq "Hibernate" ? [System.Windows.Forms.PowerState]::Hibernate : [System.Windows.Forms.PowerState]::Suspend
                [System.Windows.Forms.Application]::SetSuspendState($PowerState, $Force, $DisableWake)
            }
            ([OS]::Linux) {
                systemctl $State.ToLower() $($Force ? "--force" : [string]::Empty)
            }
            ([OS]::MacOS) {
                sudo pmset -a hibernatemode $($State -eq "Hibernate" ? 25 : 3)
                pmset sleepnow
            }
        }
    }
}

function Set-EnvironmentVariable {
    [OutputType([void])]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Low")]
    param(
        [Parameter(Position = 0)]
        [string] $Key = "PATH",

        [Parameter(Position = 1, Mandatory)]
        [string] $Value,

        [Parameter(Position = 2)]
        [EnvironmentVariableTarget] $Scope = [EnvironmentVariableTarget]::Process,

        [switch] $Override,

        [switch] $Force
    )

    begin {
        $Token = [OperatingSystem]::IsWindows() ? ";" : ":"
        $OldValue = $Override.IsPresent ? [string]::Empty : [Environment]::GetEnvironmentVariable($Key, $Scope)
        $NewValue = $OldValue.Length ? [string]::Join($Token, $OldValue, $Value) : $Value
    }
    process {
        if ($PSCmdlet.ShouldProcess($null, "Are you sure that you want to add '$Value' to the environment variable '$Key'?", "Add '$Value' to '$Key'")) {
            $IsDuplicatedValue = $($OldValue -Split $Token).Contains($Value)

            if ($IsDuplicatedValue) {
                Write-Warning "The value '$Value' already exists for the key '$Key'."

                if (!$Force) {
                    $Message = "To add a value to an existing key multiple times, use the -Force flag."
                    Write-Information -MessageData $Message -Tags "Instructions" -InformationAction Continue
                    return
                }

                Write-Warning "Forcing addition due to the -Force flag."
            }

            [Environment]::SetEnvironmentVariable($Key, $NewValue, $Scope)
        }
    }
}

function Get-EnvironmentVariable {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string] $Key = "PATH",

        [Parameter(Position = 1)]
        [EnvironmentVariableTarget] $Scope = [EnvironmentVariableTarget]::Process
    )

    begin {
        $Token = [OperatingSystem]::IsWindows() ? ";" : ":"
    }
    process {
        $EnvironmentVariables = [Environment]::GetEnvironmentVariable($Key, $Scope)

        if ($EnvironmentVariables.Length -eq 0) {
            Write-Warning "Environment variable '$Key' is empty or not defined."
            return
        }

        $EnvironmentVariableArray = $EnvironmentVariables -Split $Token
        Write-Output $EnvironmentVariableArray
    }
}

function Remove-EnvironmentVariable {
    [OutputType([void])]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param(
        [Parameter(Position = 0, Mandatory)]
        [string] $Key,

        [Parameter(Position = 1)]
        [string] $Value,

        [EnvironmentVariableTarget] $Scope = [EnvironmentVariableTarget]::Process
    )

    begin {
        $Token = [OperatingSystem]::IsWindows() ? ";" : ":"
    }
    process {
        $Title = "Remove '$Value' from '$Key'"
        $Description = "Are you sure that you want to remove '$Value' from the environment variable '$Key'?"
        $RemoveValue = $([Environment]::GetEnvironmentVariable($Key, $Scope) -Split $Token | Where-Object { $_ -ne $Value }) -Join $Token

        if (!$PSBoundParameters.ContainsKey("Value")) {
            $Title = "Remove all values in '$Key'"
            $Description = "Are you sure that you want to remove the environment variable '$Key'?"
            $RemoveValue = $null
        }

        if ($PSCmdlet.ShouldProcess($null, $Description, $Title)) {
            [Environment]::SetEnvironmentVariable($Key, $RemoveValue, $Scope)
        }
    }
}

function Get-Definition {
    param(
        [string] $Command
    )

    process {
        $(Get-Command $Command).Definition | bat --language powershell
    }
}

function Start-Timer {
    [OutputType([void])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = "Seconds")]
        [int] $Seconds,

        [Parameter(Mandatory, ParameterSetName = "Minutes")]
        [int] $Minutes,

        [Parameter(Mandatory, ParameterSetName = "Hours")]
        [int] $Hours
    )

    begin {
        $CountDown = switch ($PSCmdlet.ParameterSetName) {
            "Seconds" {
                $Seconds
            }
            "Minutes" {
                $Minutes * 60
            }
            "Hours" {
                $Hours * 3600
            }
        }

        $StartDate = [DateTime]::Now
        $StopWatch = [Stopwatch]::StartNew()
        [int] $t = 0
    }
    process {
        while ($t -le $CountDown) {
            [int] $PercentComplete = [Math]::Round($t * 100 / $CountDown, 0)
            Write-Progress -Activity "Timer" -Status "$PercentComplete%" -PercentComplete $PercentComplete -SecondsRemaining ($CountDown - $t)
            $t = $StopWatch.Elapsed.TotalSeconds
        }
    }
    end {
        Write-Verbose "Timer finished after $CountDown seconds (start date: $StartDate)"
    }
}

function Start-ElevatedConsole {
    Start-Process (Get-Process -Id $PID).Path -Verb RunAs -ArgumentList @("-NoExit", "-Command", "Set-Location '$($PWD.Path)'")
}

function Export-Branch {
    [OutputType([void])]
    [Alias("git-fire")]
    param(
        [string] $Message,

        [int] $ShutdownDelay = 15
    )

    begin {
        $Author = git config user.name
        $Remotes = git remote
        $CurrentBranch = git branch --show-current
        $NewBranch = "fire/$CurrentBranch/${env:COMPUTERNAME}/${env:USERNAME}"

        $IsValidBranch = $(git check-ref-format --branch $NewBranch 2>&1) -eq $NewBranch

        git fetch --all --quiet
        $RemoteBranches = git branch --remote --format="%(refname:lstrip=3)"

        if (!$IsValidBranch -or $RemoteBranches.Contains($NewBranch)) {
            $Salt = Get-Salt -MaxLength 16
            $RandomString = [BitConverter]::ToString($Salt).Replace("-", [string]::Empty)
            $NewBranch = "fire/$CurrentBranch/$RandomString"
         }

        Push-Location $(git rev-parse --show-toplevel)
    }
    process {
        Write-Host "$Author, leave the building now!".ToUpper()  -ForegroundColor Red
        Write-Host "We will take it from here.`n"

        Write-Host "[1/4] Creating a new branch and moving all files to the staging area" -ForegroundColor Yellow
        git checkout -b $NewBranch
        git add --all

        Write-Host "[2/4] Committing WIP" -ForegroundColor Yellow
        $DefaultMessage = "🔥 Fire! If you are in the same building as $Author, evacuate immediately!"
        $Message = $PSBoundParameters.ContainsKey("Message") ?  $Message : $DefaultMessage
        git commit -m $Message --no-verify --no-gpg-sign

        Write-Host "[3/4] Push last commit to all remotes" -ForegroundColor Yellow
        $Remotes | ForEach-Object { git push --set-upstream $_ $NewBranch --no-verify }

        Write-Host "[4/4] Push all notes to all remotes" -ForegroundColor Yellow
        $Remotes | ForEach-Object { git push $_ refs/notes/* --no-verify }
    }
    clean {
        Pop-Location

        $ExitMessage = "Turn around and evacuate the building immediately".ToUpper()
        $InfoMessage = "This computer will shutdown automatically in $ShutdownDelay seconds . . ."

        switch ($global:OperatingSystem) {
            ([OS]::Windows) {
                shutdown.exe /s /f /t $ShutdownDelay /d P:4:1 /c $([string]::Format("{0}`n`n{1}", $ExitMessage, $InfoMessage))
             }
            ([OS]::Linux) {
                Write-Host $ExitMessage -ForegroundColor Red
                Write-Host $InfoMessage
                sleep $ShutdownDelay
                systemctl poweroff
            }
        }
    }
}

function Start-DailyTranscript {
    [Alias("transcript")]
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [string] $OutputDirectory = $global:Documents
    )

    begin {
        $Transcripts = [Path]::Combine($OutputDirectory, "Transcripts")

        if (!(Test-Path $Transcripts)) {
            New-Item -Path $Transcripts -ItemType Directory | Out-Null
        }

        $Filename = [Path]::Combine($Transcripts, [string]::Format("{0}.txt", [datetime]::Now.ToString("yyyy-MM-dd")))
    }
    process {
        if ($env:PROFILE_ENABLE_DAILY_TRANSCRIPTS -eq 1) {
            Write-Verbose "Started a new transcript, output file is $Filename"
            Start-Transcript -Path $Filename -Append -IncludeInvocationHeader -UseMinimalHeader | Out-Null
        }
    }
    end {
        Write-Output $Filename
    }
}

function Get-ExecutionTime {
    $History = Get-History
    $ExecTime = $History ? ($History[-1].EndExecutionTime - $History[-1].StartExecutionTime) : (New-TimeSpan)
    Write-Output $ExecTime
}

#endregions functions

#regions argument completers

$EnvironmentVariableKeyCompleter = {
    param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParameters)

    $Scope = $FakeBoundParameters.ContainsKey("Scope") ? $FakeBoundParameters.Scope : [EnvironmentVariableTarget]::Process
    [Environment]::GetEnvironmentVariables($Scope).Keys | ForEach-Object { [CompletionResult]::new($_) }
}

@("Get-EnvironmentVariable", "Set-EnvironmentVariable", "Remove-EnvironmentVariable") | ForEach-Object {
    Register-ArgumentCompleter -CommandName $_ -ParameterName Key -ScriptBlock $EnvironmentVariableKeyCompleter
}

#endregion argument completers

#region aliases

Set-Alias -Name ^ -Value Select-Object
Set-Alias -Name man -Value Get-Help -Option AllScope
Set-Alias -Name touch -Value New-Item
Set-Alias -Name elevate -Value Start-ElevatedConsole
Set-Alias -Name activate -Value .\venv\Scripts\Activate.ps1
Set-Alias -Name np -Value notepad.exe
Set-Alias -Name exp -Value explorer.exe

#endregion aliases

function prompt {
    $ExecTime = Get-ExecutionTime

    $GitStatus = if ($(git rev-parse --is-inside-work-tree 2>&1) -eq $true) {
          #        tag                           branch                         detached head
          $Head = (git tag --points-at HEAD) ?? (git branch --show-current) ?? (git rev-parse --short HEAD)
          $DisplayUserName = $env:PROFILE_ENABLE_BRANCH_USERNAME -eq 1

          #                                         U        @     H
          Write-Output $([string]::Format(" {2}({0}{1}{2}{3}{4}{2}{5}){6}",
              $PSStyle.Foreground.Cyan,                                   # 0
              $DisplayUserName ? (git config user.name) : [string]::Empty,# 1
              $PSStyle.Foreground.Blue,                                   # 2
              $PSStyle.Foreground.BrightBlue,                             # 3
              $DisplayUserName ? "@" : [string]::Empty,                   # 4
              $Head,                                                      # 5
              $PSStyle.Foreground.White                                   # 6
          ))
    }

    $Venv = if ($env:VIRTUAL_ENV) {
        [string]::Format(" {0}({1}){2}", $PSStyle.Foreground.Magenta, [Path]::GetFileName($env:VIRTUAL_ENV), $PSStyle.Foreground.White)
    }

    $Computer = switch ($global:OperatingSystem) {
        ([OS]::Windows) {
            [PSCustomObject]@{
                UserName = $env:USERNAME
                HostName = $env:COMPUTERNAME
            }
        }
        ([OS]::Linux) {
            [PSCustomObject]@{
                UserName = $env:USER
                HostName = hostname
            }
        }
        ([OS]::MacOS) {
            [PSCustomObject]@{
                UserName = id -un
                HostName = scutil --get ComputerName
            }
        }
    }

    Start-DailyTranscript | Out-Null

    return [ArrayList]@(
        "[",
        $PSStyle.Foreground.BrightCyan,
        $Computer.UserName,
        $PSStyle.Foreground.White,
        "@",
        $Computer.HostName,
        " ",
        $PSStyle.Foreground.Green,
        [DirectoryInfo]::new($ExecutionContext.SessionState.Path.CurrentLocation).BaseName,
        $PSStyle.Foreground.White,
        "]",
        " ",
        $PSStyle.Foreground.Yellow,
        "(",
        $ExecTime.Hours.ToString("D2"),
        ":",
        $ExecTime.Minutes.ToString("D2"),
        ":",
        $ExecTime.Seconds.ToString("D2"),
        ":",
        $ExecTime.Milliseconds.ToString("D3"),
        ")",
        $PSStyle.Foreground.White,
        $GitStatus,
        $Venv,
        "`n",
        [string]::new($global:IsAdmin ? "#" : ">", $NestedPromptLevel + 1),
        " "
    ) -join ""
}
