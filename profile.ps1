using namespace System
using namespace System.Collections.Generic
using namespace System.Diagnostics
using namespace System.Globalization
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Net.Http
using namespace System.Runtime
using namespace System.Security
using namespace System.Text
using namespace System.Threading

using namespace Microsoft.PowerShell

#region configurations

$global:ProfileVersion = [PSCustomObject]@{
    Major = 1
    Minor = 6
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

    if (Get-Command "pwshfetch-test-1" -ErrorAction SilentlyContinue) {
        Set-Alias -Name neofetch -Value pwshfetch-test-1
    }

    $global:IsAdmin = ([Principal.WindowsPrincipal][Principal.WindowsIdentity]::GetCurrent()).IsInRole([Principal.WindowsBuiltInRole]::Administrator)
}

if ([OperatingSystem]::IsLinux()) {
    $global:IsAdmin = $(id -u) -eq 0
}

$global:Desktop = [Environment]::GetFolderPath("Desktop")
$global:Documents = [Environment]::GetFolderPath("MyDocuments")
$global:Natural = { [Regex]::Replace($_.Name, '\d+', { $Args[0].Value.PadLeft(20) }) }

$env:VIRTUAL_ENV_DISABLE_PROMPT = 1
$env:POWERSHELL_TELEMETRY_OPTOUT = 1
$env:POWERSHELL_UPDATECHECK = "Stable"

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

function Get-NameOf {
    [Alias("nameof")]
    [OutputType([string])]
    param(
        [scriptblock] $ScriptBlock
    )

    begin {
        $Name = $null
        $Element = @($ScriptBlock.Ast.EndBlock.Statements.PipelineElements)[0]
    }
    process {
        if($Element -is [Language.CommandExpressionAst])
        {
            switch($Element.Expression)
            {
                { $_ -is [Language.TypeExpressionAst] } { $Name = $_.TypeName.Name }
                { $_ -is [Language.MemberExpressionAst] } { $Name = $_.Member.Value }
                { $_ -is [Language.VariableExpressionAst] } { $Name = $_.VariablePath.UserPath }
            }
        }
        elseif($Element -is [Language.CommandAst])
        {
            $Name = $Element.CommandElements[0].Value
        }
    }
    end {
        Write-Output $Name
    }
}

function Update-Configuration {
    git --git-dir="$HOME\Desktop\repos\confiles" --work-tree=$HOME $Args
}

function Update-System {
    [Alias("update")]
    [OutputType([void])]
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = "Option")]
        [switch] $Help,

        [Parameter(ParameterSetName = "Option")]
        [switch] $Applications,

        [Parameter(ParameterSetName = "Option")]
        [switch] $Modules,

        [Parameter(ParameterSetName = "All")]
        [switch] $All
    )

    process {
        if ($Help.IsPresent -or $All.IsPresent) {
            Update-Help -UICulture "en-US" -ErrorAction SilentlyContinue -ErrorVariable UpdateErrors -Force
        }

        if ($Applications.IsPresent -or $All.IsPresent) {
            switch ($global:OperatingSystem) {
                ([OS]::Windows) {
                    winget upgrade --all --silent
                }
                ([OS]::Linux) {
                    apt-get update
                    apt-get full-upgrade --yes
                }
                ([OS]::MacOS) {
                    brew upgrade
                }
            }
        }

        if ($Modules.IsPresent -or $All.IsPresent) {
            $InstalledModules = @(
                "Az.Tools.Predictor"
                "Az.Accounts"
            )

            $InstalledModules | Update-Module -ErrorAction SilentlyContinue
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
        $Personalize = "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        $RegistryPath = Get-ItemProperty -Path "Registry::$Personalize"
        $RegistryPath | Set-ItemProperty -Name "AppsUseLightTheme" -Value ([int]($Theme -eq "Light"))
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
        [string] $Salt = [string]::Empty,

        [Parameter()]
        [Authentication.HashAlgorithmType] $Algorithm = [Authentication.HashAlgorithmType]::Md5
    )

    begin {
        Add-Type -AssemblyName System.Security
    }
    process {
        foreach ($s in $String) {
            $Constructor = switch ($Algorithm) {
                None { Write-Error "Algorithm must not be unset" -Category InvalidArgument -ErrorAction Stop }
                SHA1 { [Cryptography.SHA1]::Create() }
                SHA256 { [Cryptography.SHA256]::Create() }
                SHA384 { [Cryptography.SHA384]::Create() }
                SHA512 { [Cryptography.SHA512]::Create() }
                Default { [Cryptography.MD5]::Create() }
            }

            $Bytes = $Constructor.ComputeHash([Encoding]::UTF8.GetBytes($s + $Salt))
            $Hash = [BitConverter]::ToString($Bytes).Replace("-", [string]::Empty)
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
        [int] $MaxLength = 32
    )

    begin {
        $Random = [Cryptography.RNGCryptoServiceProvider]::new()
    }
    process {
        $Salt = [Byte[]]::CreateInstance([Byte], $MaxLength)
        $Random.GetNonZeroBytes($Salt)
        Write-Output $Salt
    }
    clean {
        $Random.Dispose()
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
                # On Windows, file names cannot exceed 256 bytes. Starting in Windows 10 (version 1607), the limit max
                # path limit can be extended via setting this registry key to a value of 1 (property type: DWORD)
                # https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation?tabs=registry
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
    end {
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
    <#
        .SYNOPSIS
        Generates a random password of the specified length.

        .DESCRIPTION
        Generates a random password of the specified length. The implementation of this function is based on the
        Membership.GeneratePassword method from the System.Web.Security namespace from the .NET framework.

        .PARAMETER Length
        The number of characters in the generated password. The length must be between 1 and 128 characters.

        .PARAMETER NumberOfNonAlphanumericCharacters
        The minimum number of non-alphanumeric characters (such as @, #, !, %, &, and so on) in the generated password.

        .LINK
        https://docs.microsoft.com/en-us/dotnet/api/system.web.security.membership.generatepassword?view=netframework-4.8

        .LINK
        https://referencesource.microsoft.com/#System.Web/Security/Membership.cs,302

        .EXAMPLE
        PS> Get-RandomPassword -Length 32

        .OUTPUTS
        A random password of the specified length.
    #>
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [ValidateRange(1, 128)]
        [int] $Length = 64,

        [Parameter(Position = 1)]
        [int] $NumberOfNonAlphanumericCharacters = 16
    )

    begin {
        Add-Type -AssemblyName System.Security
        [char[]] $Punctuations = "!@#$%^&*()_-+=[{]};:>|./?".ToCharArray()
        $RandomNumberGenerator = [Cryptography.RNGCryptoServiceProvider]::new()
    }
    process {
        if ($NumberOfNonAlphanumericCharacters -gt $Length -or $NumberOfNonAlphanumericCharacters -lt 0) {
            Write-Error -Message "Invalid argument for $(nameof{ $NumberOfNonAlphanumericCharacters }): '$NumberOfNonAlphanumericCharacters'" -Category InvalidArgument -ErrorAction Stop
        }

        [int] $Count = 0
        $ByteBuffer = New-Object byte[] $Length
        $CharacterBuffer = New-Object char[] $Length
        $RandomNumberGenerator.GetBytes($ByteBuffer)

        for ([int] $i = 0; $i -lt $Length; $i++) {
            [int] $j = [int]($ByteBuffer[$i] % 87)

            if ($j -lt 10) {
                $CharacterBuffer[$i] = [char]([int]([char]'0') + $j)
            }
            elseif ($j -lt 36) {
                $CharacterBuffer[$i] = [char]([int]([char]'A') + $j - 10)
            }
            elseif ($j -lt 62) {
                $CharacterBuffer[$i] = [char]([int]([char]'a') + $j - 36)
            }
            else {
                $CharacterBuffer[$i] = $Punctuations[$j - 62]
                $Count++
            }
        }

        if ($count -lt $NumberOfNonAlphanumericCharacters) {
            return $([string]::new($CharacterBuffer))
        }

        $PRNG = [Random]::new()

        for ([int] $k = 0; $k -lt $NumberOfNonAlphanumericCharacters - $Count; $k++) {
            do {
                [int] $r = $PRNG.Next(0, $Length)
            }
            while (![char]::IsLetterOrDigit($CharacterBuffer[$r]))

            $CharacterBuffer[$r] = $Punctuations[$PRNG.Next(0, $Punctuations.Count)]
        }

        return $([string]::new($CharacterBuffer))
    }
    clean {
        $RandomNumberGenerator.Dispose()
    }
}

function Stop-LocalServer {
    [Alias("killui")]
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

function New-DotnetProject {
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [string] $Path = $PWD,

        [ValidateSet("console", "classlib", "wpf", "winforms", "page", "blazorserver", "blazorwasm", "web", "mvc", "razor", "webapi")]
        [string] $Template = "console",

        [ValidateSet("C#", "F#", "VB")]
        [string] $Language = "C#",

        [string[]] $Packages,

        [switch] $InitRepository
    )

    begin {
        $OutputDirectory = Join-Path -Path $Path -ChildPath $Name -Resolve
        $RootDirectory = New-Item -ItemType Directory -Path $(Join-Path -Path $OutputDirectory -ChildPath $Name -Resolve)
        Push-Location $OutputDirectory
    }
    process {
        dotnet new $Template --name $Name --language $Language --output $RootDirectory
        dotnet new gitignore --output $OutputDirectory
        dotnet new editorconfig --output $OutputDirectory
        dotnet restore $RootDirectory
        dotnet build $RootDirectory

        $Readme = New-Item -ItemType File -Name "README.md" -Path $OutputDirectory
        Set-Content $Readme -Value "# $Name"

        if ($PSBoundParameters.ContainsKey("Packages")) {
            $Packages | ForEach-Object {
                dotnet add $RootDirectory package $_
            }
        }

        if ($InitRepository.IsPresent) {
            git init
            git add --all
            git commit -m "Init commit"
        }
    }
    clean {
        Pop-Location
    }
}

function Stop-Work {
    $Apps = @("TEAMS", "OUTLOOK", "LYNC")
    Get-Process | Where-Object { $Apps.Contains($_.Name.ToUpper()) } | Stop-Process -Force
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

        [switch] $Override
    )

    $Token = [OperatingSystem]::IsWindows() ? ";" : ":"

    $OldValue = $Override.IsPresent ? [string]::Empty : [Environment]::GetEnvironmentVariable($Key, $Scope)
    $NewValue = $OldValue.Length ? [string]::Join($Token, $OldValue, $Value) : $Value

    if ($PSCmdlet.ShouldProcess($null, "Are you sure that you want to add '$Value' to the environment variable '$Key'?", "Add '$Value' to '$Key'")) {
        [Environment]::SetEnvironmentVariable($Key, $NewValue, $Scope)
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

    $Token = [OperatingSystem]::IsWindows() ? ";" : ":"

    $EnvironmentVariables = [Environment]::GetEnvironmentVariable($Key, $Scope) -Split $Token
    Write-Output $EnvironmentVariables
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

    $Token = [OperatingSystem]::IsWindows() ? ";" : ":"

    $Title = "Remove '$Value' from '$Key'"
    $Description = "Are you sure that you want to remove '$Value' from the environment variable '$Key'?"
    $RemoveValue = $([Environment]::GetEnvironmentVariable($Key, $Scope) -Split $Token | Where-Object { $_ -ne $Value }) -join $Token

    if (!$PSBoundParameters.ContainsKey("Value")) {
        $Title = "Remove all values in '$Key'"
        $Description = "Are you sure that you want to remove the environment variable '$Key'?"
        $RemoveValue = $null
    }

    if ($PSCmdlet.ShouldProcess($null, $Description, $Title)) {
        [Environment]::SetEnvironmentVariable($Key, $RemoveValue, $Scope)
    }
}

function Measure-ScriptBlock {
    <#
        .SYNOPSIS
        Measures the time it takes to run script blocks and cmdlets.

        .DESCRIPTION
        The `Measure-ScriptBlock` cmdlet runs a script block or cmdlet internally -Round times, measures the execution of
        the operation, and returns the execution time.

        .PARAMETER ScriptBlock
        PowerShell script block to test.

        .PARAMETER Path
        Path to PowerShell script to create a script block from.

        .PARAMETER Rounds
        Defines the number of times the script block code is executed.

        .PARAMETER NoGC
        Don't invoke the garbage collector.

        .PARAMETER NoWarmUp
        Skip the warm-up routine (and omit the first 5 command invocations). The warm-up routine is used to stabilize the
        performance measurements and are not part of the actual test run.

        .NOTES
        A single tick represents one hundred nanoseconds or one ten-millionth of a second. There are 10,000 ticks in a
        millisecond (see `[System.TimeSpan]`) and 10 million ticks in a second.

        Use the built-in `Measure-Command` cmdlet from Microsoft if you only want to run the script block once.

        .EXAMPLE
        PS > $Result = timeit -ScriptBlock { prompt | Out-Null } -Rounds 100 -Verbose

        Always pipe the script block section to `Out-Null` so that the result of the command being run doesn't get mixed
        up with the measurements returned by `Measure-ScriptBlock`.

        .EXAMPLE
        PS > $Result = Measure-ScriptBlock -Path .\script.ps1 -Rounds 10000 -Verbose

        You can also test scripts directly. Here you don't have to pipe anything to `Out-Null`.

        .EXAMPLE
        PS > $ScriptBlock = { Get-Random -Minimum 1 -Maximum 1000 | Out-Null }
        PS > $Result = Measure-ScriptBlock -ScriptBlock $ScriptBlock -Rounds 10000 -Verbose
        PS > $Result.Average / [System.TimeSpan]::TicksPerSecond

        You can convert elapsed ticks to seconds (or minutes, etc.) by using the fields exposed by `[System.TimeSpan]`.
    #>
    [Alias("timeit")]
    [OutputType([Microsoft.PowerShell.Commands.GenericMeasureInfo])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = "ScriptBlock")]
        [scriptblock] $ScriptBlock,

        [Parameter(Mandatory, ParameterSetName = "Path")]
        [string] $Path,

        [Parameter(Mandatory)]
        [int] $Rounds,

        [Parameter()]
        [switch] $NoGC,

        [Parameter()]
        [switch] $NoWarmUp
    )

    begin {
        $StopWatch = [Stopwatch]::new()
        $Measurements = New-Object List[System.TimeSpan]

        if (![Stopwatch]::IsHighResolution) {
            Write-Error -Message "Your hardware doesn't support the high resolution counter required to run this test" -Category DeviceError -ErrorAction Stop
        }

        $Command = switch ($PSCmdlet.ParameterSetName) {
            "ScriptBlock" { $ScriptBlock }
            "Path" { Get-Command $Path | Select-Object -ExpandProperty ScriptBlock }
        }

        $CurrentProcess = [Process]::GetCurrentProcess()
        $CurrentProcess.ProcessorAffinity = [IntPtr]::new(2)
        $CurrentProcess.PriorityClass = [ProcessPriorityClass]::High
        [Thread]::CurrentThread.Priority = [ThreadPriority]::Highest

        if (!$NoGC.IsPresent) {
            Write-Verbose "Calling garbage collector and waiting for pending finalizers . . ."
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
        }

        if (!$NoWarmUp.IsPresent) {
            [int] $Reps = 5
            Write-Verbose "Running warmup routine . . ."

            while ($Repos -ge 0) {
                Invoke-Command -ScriptBlock $Command
                $Reps--
            }
        }
    }
    process {
        Write-Verbose "Running performance test . . ."

        for ($r = 0; $r -lt $Rounds; $r++) {
            $StopWatch.Restart()
            Invoke-Command -ScriptBlock $Command
            $StopWatch.Stop()
            $Measurements.Add($StopWatch.Elapsed)
        }
    }
    end {
        Write-Output $($Measurements | Measure-Object -Property Ticks -AllStats)
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
Set-Alias -Name config -Value Update-Configuration
Set-Alias -Name bye -Value Stop-Work
Set-Alias -Name elevate -Value Start-ElevatedConsole
Set-Alias -Name activate -Value .\venv\Scripts\Activate.ps1
Set-Alias -Name np -Value notepad.exe
Set-Alias -Name exp -Value explorer.exe

#endregion aliases

function prompt {
    $ExecTime = Get-ExecutionTime

    $Branch = if ($(git rev-parse --is-inside-work-tree 2>&1) -eq $true) {
          [string]::Format(" {0}({1}){2}", $PSStyle.Foreground.Blue, $(git branch --show-current), $PSStyle.Foreground.White)
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

    return [System.Collections.ArrayList]@(
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
        $Branch,
        $Venv,
        "`n",
        [string]::new($global:IsAdmin ? "#" : ">", $NestedPromptLevel + 1),
        " "
    ) -join ""
}
