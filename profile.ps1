#region configurations

$PSDefaultParameterValues['*:Encoding'] = "utf8"

if ([System.OperatingSystem]::IsWindows()) {
    $global:PSRC = "$HOME\Documents\PowerShell\profile.ps1"
    $global:VSRC = "$env:APPDATA\Code\User\settings.json"
    $global:VIRC = "$env:LOCALAPPDATA\nvim\init.vim"
    $global:WTRC = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $global:WGRC = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json"
}

$global:Desktop = [Environment]::GetFolderPath("Desktop")
$global:Natural = { [Regex]::Replace($_.Name, '\d+', { $Args[0].Value.PadLeft(20) }) }

$env:VIRTUAL_ENV_DISABLE_PROMPT = 1
$env:POWERSHELL_TELEMETRY_OPTOUT = 1
$env:POWERSHELL_UPDATECHECK = "Stable"

$PSStyle.Progress.View = "Classic"
$Host.PrivateData.ProgressBackgroundColor = "Cyan"
$Host.PrivateData.ProgressForegroundColor = "Yellow"

Set-PSReadLineOption -PredictionSource History
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

#endregion configurations

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
        if($Element -is [System.Management.Automation.Language.CommandExpressionAst])
        {
            switch($Element.Expression)
            {
                { $_ -is [System.Management.Automation.Language.TypeExpressionAst] } { $Name = $_.TypeName.Name }
                { $_ -is [System.Management.Automation.Language.MemberExpressionAst] } { $Name = $_.Member.Value }
                { $_ -is [System.Management.Automation.Language.VariableExpressionAst] } { $Name = $_.VariablePath.UserPath }
            }
        }
        elseif($Element -is [System.Management.Automation.Language.CommandAst])
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
    Update-Help -UICulture "en-US" -ErrorAction SilentlyContinue -ErrorVariable UpdateErrors -Force
}

function Export-Icon {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Low")]
    param(
        [Parameter(Mandatory, HelpMessage = "Path to SVG file")]
        [string] $Path,

        [Parameter()]
        [string] $Destination = $CWD
    )

    begin {
        [int] $Size = 1024
        $File = Get-Item -Path $Path

        if ($File.Extension -ne ".svg") {
            Write-Error -Message "Not a SVG file" -Category InvalidArgument -ErrorAction Stop
        }
    }
    process {
        if ($PSCmdlet.ShouldProcess($File.Name)) {
            while ($Size -gt 16) {
                $FullName = Join-Path -Path $Destination -ChildPath "$($Size)x$($Size)-$($File.BaseName).png"
                Write-Verbose "Exporting ${Fullname} . . ."
                inkscape $Path -w $Size -h $Size -o $FullName
                $Size /= 2
            }
        }
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
        [System.Security.Authentication.HashAlgorithmType] $Algorithm = [System.Security.Authentication.HashAlgorithmType]::Md5
    )

    begin {
        Add-Type -AssemblyName System.Security
    }
    process {
        foreach ($s in $String) {
            $Constructor = switch ($Algorithm) {
                None { Write-Error "Algorithm must not be unset" -Category InvalidArgument -ErrorAction Stop }
                SHA1 { [System.Security.Cryptography.SHA1]::Create() }
                SHA256 { [System.Security.Cryptography.SHA256]::Create() }
                SHA384 { [System.Security.Cryptography.SHA384]::Create() }
                SHA512 { [System.Security.Cryptography.SHA512]::Create() }
                Default { [System.Security.Cryptography.MD5]::Create() }
            }

            $Bytes = $Constructor.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($s + $Salt))
            $Hash = [System.BitConverter]::ToString($Bytes).Replace("-", [string]::Empty)
            Write-Output $Hash
        }
    }
    end {
        $Constructor.Dispose()
    }
}

function Get-FileSize {
    [OutputType([double])]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [string[]] $Path,

        [Parameter()]
        [ValidateSet('B', 'KB', 'MB', 'GB', 'TB', 'PB')]
        [string] $Unit = 'B'
    )

    process {
        foreach ($p in $Path) {
            $FileInfo = [System.IO.FileInfo]::new($p)
            $Length = $FileInfo.Length

            $Size = switch ($Unit) {
                PB { $Length / 1PB }
                TB { $Length / 1TB }
                GB { $Length / 1GB }
                MB { $Length / 1MB }
                KB { $Length / 1KB }
                Default { $Length }
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

        [System.IO.SearchOption] $SearchOption = [System.IO.SearchOption]::TopDirectoryOnly
    )

    process {
        foreach ($p in $Path) {
            $FileCount = [System.IO.Directory]::GetFiles($p, "*", $SearchOption).Length
            Write-Output $FileCount
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
        $RandomNumberGenerator = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    }
    process {
        if ($NumberOfNonAlphanumericCharacters -gt $Length || $NumberOfNonAlphanumericCharacters -lt 0) {
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

        $PRNG = [System.Random]::new()

        for ([int] $k = 0; $k -lt $NumberOfNonAlphanumericCharacters - $Count; $k++) {
            do {
                [int] $r = $PRNG.Next(0, $Length)
            }
            while (-not [char]::IsLetterOrDigit($CharacterBuffer[$r]))

            $CharacterBuffer[$r] = $Punctuations[$PRNG.Next(0, $Punctuations.Count)]
        }

        return $([string]::new($CharacterBuffer))
    }
    end {
        $RandomNumberGenerator.Dispose()
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
        $TimeZoneInfo = [System.TimeZoneInfo]::FindSystemTimeZoneById($TimeZoneId)
        $Date = [System.TimeZoneInfo]::ConvertTimeFromUtc([System.DateTime]::Now.ToUniversalTime(), $TimeZoneInfo)

        Write-Output $([PSCustomObject]@{
            Offset     = $TimeZoneInfo.GetUtcOffset([System.DateTimeKind]::Local).Hours
            Date       = $Date.ToShortDateString()
            Time       = $Date.ToString("HH:mm:ss")
            Name       = $TimeZoneInfo.StandardName
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
    hidden [System.Net.Http.HttpClient] $Client

    [void] Download([bool] $Force = $false) {
        [System.Net.Http.HttpResponseMessage] $Response = $this.Client.GetAsync($this.Img).GetAwaiter().GetResult()
        $Response.EnsureSuccessStatusCode()
        $ReponseStream = $Response.Content.ReadAsStream()

        if ([System.IO.File]::Exists($this.Path) -and $Force) {
            Write-Warning -Message "$($this.Path) already exists, deleting file"
            [System.IO.File]::Delete($this.Path)
        }

        $FileStream = [System.IO.FileStream]::new($this.Path, [System.IO.FileMode]::Create)
        $ReponseStream.CopyTo($FileStream)
        $FileStream.Close()
    }

    XKCD([int] $Id, [string] $Path, [System.Net.Http.HttpClient] $Client) {
        $this.Client = $Client
        $Response = ConvertFrom-Json $this.Client.GetStringAsync("https://xkcd.com/$Id/info.0.json").GetAwaiter().GetResult()

        $this.Id = $Response.Num
        $this.Title = $Response.Title
        $this.Alt = $Response.Alt
        $this.Img = $Response.Img
        $this.Date = [System.DateTime]::new($Response.Year, $Response.Month, $Response.Day)
        $this.Path = [System.IO.Path]::Combine($Path, "$($Response.Num).$($this.Img.Split("/")[-1].Split(".")[1])")
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
        $Client = [System.Net.Http.HttpClient]::new()
        [void] $Client.DefaultRequestHeaders.UserAgent.TryParseAdd("${env:USERNAME}@profile.ps1")
        [void] $Client.DefaultRequestHeaders.Accept.Add([System.Net.Http.Headers.MediaTypeWithQualityHeaderValue]::new("application/json"))

        $Info = if (-not $MyInvocation.BoundParameters.ContainsKey("Number") -or $null -eq $Number) {
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
                @([System.Random]::new().Next(1, $Info.Num))
            }
            default {
                ($Info.Num - $Last + 1)..$Info.Num
            }
        }

        foreach ($Id in $Ids) {
            $XKCD = [XKCD]::new($Id, $Path, $Client)

            if (-not $NoDownload.IsPresent -and $PSCmdlet.ShouldProcess($XKCD.Img, "Download $($XKCD.Path)")) {
                $XKCD.Download($Force.IsPresent)
            }

            Write-Output $XKCD
        }
    }
}

function Set-PowerState {
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
        if ([System.OperatingSystem]::IsWindows()) {
            Add-Type -AssemblyName System.Windows.Forms
            $PowerState = $PowerState -eq "Hibernate" ? [System.Windows.Forms.PowerState]::Hibernate : [System.Windows.Forms.PowerState]::Suspend
            [System.Windows.Forms.Application]::SetSuspendState($PowerState, $Force, $DisableWake)
        }
        elseif ([System.OperatingSystem]::IsLinux()) {
            systemctl $State.ToLower() $($Force ? "--force" : [string]::Empty)
        }
        else { # macOS
            sudo pmset -a hibernatemode $($State -eq "Hibernate" ? 25 : 3)
            pmset sleepnow
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
        [System.EnvironmentVariableTarget] $Scope = [System.EnvironmentVariableTarget]::User
    )

    $NewValue = [Environment]::GetEnvironmentVariable($Key, $Scope) + ";${Value}"

    if ($PSCmdlet.ShouldProcess("Adding $Value to $Key", "Are you sure you want to add '$Value' to the environment variable '$Key'?", "Add '$Value' to '$Key'")) {
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
        [System.EnvironmentVariableTarget] $Scope = [System.EnvironmentVariableTarget]::User
    )

    $EnvironmentVariables = [Environment]::GetEnvironmentVariable($Key, $Scope) -Split ";"
    Write-Output $EnvironmentVariables
}

function Remove-EnvironmentVariable {
    [OutputType([void])]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param(
        [Parameter(Position = 0, Mandatory)]
        [string] $Key,

        [Parameter()]
        [string] $Value,

        [System.EnvironmentVariableTarget] $Scope = [System.EnvironmentVariableTarget]::User
    )

    $RemoveValue = $Key -eq "PATH" ? $([Environment]::GetEnvironmentVariable("PATH", $Scope) -Split ";" | Where-Object { $_ -ne $Value }) -join ";" : $null

    if ($PSCmdlet.ShouldProcess("Removing value '$Value' from environment variable '$Key'", "Are you sure you want to remove '$Value' from the environment variable '$Key'?", "Remove '$Value' from '$Key'")) {
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
        $StopWatch = [System.Diagnostics.Stopwatch]::new()
        $Measurements = New-Object System.Collections.Generic.List[System.TimeSpan]

        if (-not [System.Diagnostics.Stopwatch]::IsHighResolution) {
            Write-Error -Message "Your hardware doesn't support the high resolution counter required to run this test" -Category DeviceError -ErrorAction Stop
        }

        $Command = switch ($PSCmdlet.ParameterSetName) {
            "ScriptBlock" { $ScriptBlock }
            "Path" { Get-Command $Path | Select-Object -ExpandProperty ScriptBlock }
        }

        $CurrentProcess = [System.Diagnostics.Process]::GetCurrentProcess()
        $CurrentProcess.ProcessorAffinity = [System.IntPtr]::new(2)
        $CurrentProcess.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
        [System.Threading.Thread]::CurrentThread.Priority = [System.Threading.ThreadPriority]::Highest

        if (-not $NoGC.IsPresent) {
            Write-Verbose "Calling garbage collector and waiting for pending finalizers . . ."
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
        }

        if (-not $NoWarmUp.IsPresent) {
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

function Get-ExecutionTime {
    $History = Get-History
    $ExecTime = if ($History) { $History[-1].EndExecutionTime - $History[-1].StartExecutionTime } else { New-TimeSpan }
    Write-Output $ExecTime
}

#endregions functions

#region aliases

Set-Alias -Name ^ -Value Select-Object
Set-Alias -Name man -Value Get-Help -Option AllScope
Set-Alias -Name touch -Value New-Item
Set-Alias -Name config -Value Update-Configuration
Set-Alias -Name update -Value Update-System
Set-Alias -Name bye -Value Stop-Work
Set-Alias -Name np -Value notepad.exe
Set-Alias -Name exp -Value explorer.exe

#endregion aliases

function prompt {
    $ExecTime = Get-ExecutionTime
    $ResetForeground = [string]::Intern($PSStyle.Foreground.White)

    $Branch = if ($(git rev-parse --is-inside-work-tree 2>&1) -eq $true) {
          [string]::Format(" {0}({1}){2}", $PSStyle.Foreground.Blue, $(git branch --show-current), $ResetForeground)
    }

    $Venv = if ($env:VIRTUAL_ENV) {
        [string]::Format(" {0}({1}){2}", $PSStyle.Foreground.Magenta, [System.IO.Path]::GetFileName($env:VIRTUAL_ENV), $ResetForeground)
    }

    return [System.Collections.ArrayList]@(
        "[",
        $PSStyle.Foreground.BrightCyan,
        $env:USERNAME,
        $ResetForeground,
        "@",
        $env:COMPUTERNAME,
        " ",
        $PSStyle.Foreground.Green,
        [System.IO.DirectoryInfo]::new($ExecutionContext.SessionState.Path.CurrentLocation).BaseName,
        $ResetForeground,
        "]",
        " ",
        $PSStyle.Foreground.Yellow,
        "(",
        $ExecTime.Hours.ToString('D2'),
        ":",
        $ExecTime.Minutes.ToString('D2'),
        ":",
        $ExecTime.Seconds.ToString('D2'),
        ":",
        $ExecTime.Milliseconds.ToString('D3'),
        ")",
        $ResetForeground,
        $Branch,
        $Venv,
        "`n",
        [string]::new(">", $NestedPromptLevel + 1),
        " "
    ) -join ''
}
