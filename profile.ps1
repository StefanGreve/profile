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

$PSStyle.Progress.View = "Classic"
$Host.PrivateData.ProgressBackgroundColor = "Cyan"
$Host.PrivateData.ProgressForegroundColor = "Yellow"

#endregion configurations

#region functions

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
        [ValidateSet('B', 'KB', 'MB', 'GB', 'TB')]
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
        [string[]] $Path
    )

    process {
        foreach ($p in $Path) {
            $FileCount = [System.IO.Directory]::GetFiles($p, "*", [System.IO.SearchOption]::AllDirectories).Length
            Write-Output $FileCount
        }
    }
}

function New-Password {
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [int] $Length = 64,

        [Parameter(Position = 1)]
        [int] $NumberOfNonAlphanumericCharacters = 16
    )

    Add-Type -AssemblyName System.Web
    $Password = [System.Web.Security.Membership]::GeneratePassword($Length, $NumberOfAlphanumericCharacters)
    Write-Output $Password
}

function Get-Uptime {
    Write-Output $((Get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime)
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
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string] $Key = "PATH",

        [Parameter(Position = 1, Mandatory)]
        [string] $Value,

        [Parameter(Position = 2)]
        [System.EnvironmentVariableTarget] $Scope = [System.EnvironmentVariableTarget]::User
    )

    $NewValue = [Environment]::GetEnvironmentVariable($Key, $Scope) + ";${Value}"
    [Environment]::SetEnvironmentVariable($Key, $NewValue, $Scope)
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
    $ExampleOutput = $Key -eq "PATH" ? "`n`n$($PSStyle.Foreground.Green)NEW PATH VALUE`n==============$($PSStyle.Foreground.White)`n`n$($RemoveValue -split ";" -join "`n")`n`n" : $null

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
    $Time = " ($($ExecTime.Hours.ToString('D2')):$($ExecTime.Minutes.ToString('D2')):$($ExecTime.Seconds.ToString('D2')):$($ExecTime.Milliseconds.ToString('D3')))"

    git rev-parse --is-inside-work-tree 2>&1 | Out-Null

    $Branch = if ($?) {
        $PSStyle.Foreground.Blue + " ($(git branch --show-current))" + $PSStyle.Foreground.White
    }

    $Venv = if ($env:VIRTUAL_ENV) {
        $PSStyle.Foreground.Yellow + " ($([System.IO.Path]::GetFileName($env:VIRTUAL_ENV))" + $PSStyle.Foreground.White
    }

    $Path = (Get-Item "$($ExecutionContext.SessionState.Path.CurrentLocation)").BaseName

    return @(
        '[',
        $PSStyle.Foreground.BrightCyan + $env:USERNAME + $PSStyle.Foreground.White,
        '@',
        $env:COMPUTERNAME,
        ' ',
        $PSStyle.Foreground.Green + $Path + $PSStyle.Foreground.White,
        ']'
        $Branch,
        $Venv,
        $PSStyle.Foreground.BrightYellow + $Time + $PSStyle.Foreground.White,
        "`n",
        "$('>' * ($NestedPromptLevel + 1)) "
    ) -join ''
}
