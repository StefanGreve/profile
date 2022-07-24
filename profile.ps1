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

function Get-NameOf
{
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

function Set-PowerState {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param(
        [ValidateSet("Hibernate", "Suspend")]
        [Parameter(Position = 0)]
        [string] $State = "Suspend",

        [switch] $Force,

        [Parameter(ParameterSetName = "Windows")]
        [switch] $DisableWake
    )

    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, $State)) {
        if ([System.OperatingSystem]::IsWindows()) {
            Add-Type -AssemblyName System.Windows.Forms
            $State = $State -eq "Hibernate" ? [System.Windows.Forms.PowerState]::Hibernate : [System.Windows.Forms.PowerState]::Suspend
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
    $ExampleOutput = "`n$($PSStyle.Foreground.Yellow)$($NewValue -split ";" -join "`n")$($PSStyle.Foreground.White)`n`n"

    if ($PSCmdlet.ShouldProcess("Adding $Value to $Key", "Are you sure you want to add '$Value' to the environment variable '$Key'?$ExampleOutput", "Add '$Value' to '$Key'")) {
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
    $ExampleOutput = $Key -eq "PATH" ? "`n`n$($PSStyle.Foreground.Yellow)$($RemoveValue -split ";" -join "`n")$($PSStyle.Foreground.White)`n`n" : $null

    if ($PSCmdlet.ShouldProcess("Removing value '$Value' from environment variable '$Key'", "Are you sure you want to remove '$Value' from the environment variable '$Key'?$ExampleOutput", "Remove '$Value' from '$Key'")) {
        [Environment]::SetEnvironmentVariable($Key, $RemoveValue, $Scope)
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
