using namespace System
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Security
using namespace System.Text

using namespace Microsoft.PowerShell

# settings.json lives next to the profile link itself
$SettingsPath = [Path]::Join([Path]::GetDirectoryName($PSCommandPath), "settings.json")
$SettingsFile = if (Test-Path $SettingsPath) {
    Get-Content -Path $SettingsPath | ConvertFrom-Json
} else {
    [PSCustomObject]@{
        DefaultCulture = "en-US"
        DefaultEncoding = "utf8"
        Modules = @("PowerTools")
    }
}

[CultureInfo]::CurrentCulture = [CultureInfo]::CreateSpecificCulture($SettingsFile.DefaultCulture)
$PSDefaultParameterValues["*:Encoding"] = $SettingsFile.DefaultEncoding
$ErrorView = "ConciseView"

if ($SettingsFile.EnableClassicProgressbar -eq $true) {
    $PSStyle.Progress.View = "Classic"
    $Host.PrivateData.ProgressBackgroundColor = "Cyan"
    $Host.PrivateData.ProgressForegroundColor = "Yellow"
}

# Mirrors Test-Elevation so this profile doesn't depend on the PowerTools module
$global:IsAdmin = if ($IsWindows) {
    $CurrentUser = [Principal.WindowsPrincipal][Principal.WindowsIdentity]::GetCurrent()
    $Administrator = [Principal.WindowsBuiltInRole]::Administrator
    $CurrentUser.IsInRole($Administrator)
} elseif ($IsLinux -or $IsMacOS) {
    $(id -u) -eq 0
} else {
    $null
}

if ($IsWindows) {
    $global:Natural = { [Regex]::Replace($_.Name, "\d+", { $Args[0].Value.PadLeft(20) }) }
}

foreach ($Module in $SettingsFile.Modules) {
    if (Get-Module -Name $Module -ListAvailable) {
        Import-Module -Name $Module
    } else {
        Write-Warning "The configured module `"$Module`" is not installed; skipping import."
    }
}

if (![string]::IsNullOrWhiteSpace($SettingsFile.DotSourceDirectory)) {
    $DotSourceDirectory = [Environment]::ExpandEnvironmentVariables($SettingsFile.DotSourceDirectory)

    if (!(Test-Path $DotSourceDirectory)) {
        Write-Warning "DotSourceDirectory `"$($DotSourceDirectory)`" does not exist; no scripts were dot-sourced."
    } else {
        Get-ChildItem -Path $DotSourceDirectory -Filter "*.ps1"
            | ForEach-Object { . $_.FullName }
    }
}

# Required by Python for custom virtual environment status indicator in prompt function
$env:VIRTUAL_ENV_DISABLE_PROMPT = 1

#region Aliases

Set-Alias -Name ^ -Value Select-Object

if ($IsWindows) {
    Set-Alias -Name man -Value Get-Help -Option AllScope
    Set-Alias -Name touch -Value New-Item
    Set-Alias -Name activate -Value ".\venv\Scripts\Activate.ps1"
    Set-Alias -Name np -Value notepad.exe
    Set-Alias -Name exp -Value explorer.exe
}

#endregion

#region PSReadLine Configuration

Set-PSReadLineOption -PredictionSource HistoryAndPlugin `
    -PredictionViewStyle ListView `
    -HistoryNoDuplicates `
    -HistorySearchCursorMovesToEnd `
    -ShowToolTips `
    -EditMode Windows `
    -BellStyle None

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

Set-PSReadLineKeyHandler -Key "(", "[", "{" -BriefDescription InsertPairedBraces -LongDescription "Insert matching braces" -ScriptBlock {
    param($Key, $Arg)

    $CloseChar = switch ($Key.KeyChar) {
        <#case#> "(" { [char]")"; break }
        <#case#> "[" { [char]"]"; break }
        <#case#> "{" { [char]"}"; break }
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

Set-PSReadLineKeyHandler -Key ")", "]", "}" -BriefDescription SmartClosingBraces -LongDescription "Insert closing brace or skip" -ScriptBlock {
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

#endregion

#region Tab Completions

if (Get-Command "dotnet" -ErrorAction SilentlyContinue) {
    dotnet completions script pwsh | Out-String | Invoke-Expression
}

#region Dotnet Suggest Shell Start
if (Get-Command "dotnet-suggest" -ErrorAction SilentlyContinue) {
    $AvailableToComplete = (dotnet-suggest list) | Out-String
    $AvailableToCompleteArray = $AvailableToComplete.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)

    Register-ArgumentCompleter -Native -CommandName $AvailableToCompleteArray -ScriptBlock {
        param($WordToComplete, $CommandAst, $CursorPosition)

        $FullPath = (Get-Command $CommandAst.CommandElements[0]).Source
        $Arguments = $CommandAst.Extent.ToString().Replace('"', '\"')

        dotnet-suggest get -e $FullPath --position $CursorPosition -- "$Arguments" | ForEach-Object {
            [CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
} else {
    "Unable to provide System.CommandLine tab completion support unless the [dotnet-suggest] tool is first installed."
    "See the following for tool installation: https://www.nuget.org/packages/dotnet-suggest"
}

$env:DOTNET_SUGGEST_SCRIPT_VERSION = "1.0.2"
#endregion

# Opt-in per tool; the more completions you enable, the slower the profile loads. Except for winget,
# each block below spawns the tool and pipes its emitted script through Invoke-Expression at load, so
# the parse cost scales with the script size noted above each registration.
$NativeCompletions = $SettingsFile.RegisterNativeCompletions

if (($NativeCompletions -contains "winget") -and (Get-Command "winget" -ErrorAction SilentlyContinue)) {
    # winget is a native C++ application, so it exposes its own completion backend
    # independent of what dotnet-suggest is built upon. Registers a static scriptblock and defers the
    # winget complete subprocess to completion time, so its impact on profile load is negligible.
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($WordToComplete, $CommandAst, $CursorPosition)

        [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
        $Local:Word = $WordToComplete.Replace('"', '""')
        $Local:Ast = $CommandAst.ToString().Replace('"', '""')

        winget complete --word="$Local:Word" --commandline "$Local:Ast" --position $CursorPosition | ForEach-Object {
            [CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

# gh emits a ~11 KB completion script; light impact on profile load.
if (($NativeCompletions -contains "gh") -and (Get-Command "gh" -ErrorAction SilentlyContinue)) {
    gh completion --shell powershell | Out-String | Invoke-Expression
}

# bat emits an ~18 KB completion script; light impact on profile load.
if (($NativeCompletions -contains "bat") -and (Get-Command "bat" -ErrorAction SilentlyContinue)) {
    bat --completion ps1 | Out-String | Invoke-Expression
}

# uv emits a very large (~730 KB) completion script; heavy impact on profile load.
if (($NativeCompletions -contains "uv") -and (Get-Command "uv" -ErrorAction SilentlyContinue)) {
    uv generate-shell-completion powershell | Out-String | Invoke-Expression
}

# pip emits a sub-1 KB completion script; negligible impact on profile load.
if (($NativeCompletions -contains "pip") -and (Get-Command "pip" -ErrorAction SilentlyContinue)) {
    pip completion --powershell | Out-String | Invoke-Expression
}

# op emits a ~10 KB completion script; light impact on profile load.
if (($NativeCompletions -contains "op") -and (Get-Command "op" -ErrorAction SilentlyContinue)) {
    op completion powershell | Out-String | Invoke-Expression
}

# delta emits a ~21 KB completion script; light impact on profile load.
if (($NativeCompletions -contains "delta") -and (Get-Command "delta" -ErrorAction SilentlyContinue)) {
    delta --generate-completion powershell | Out-String | Invoke-Expression
}

# rustup emits a ~47 KB completion script; minor impact on profile load.
if (($NativeCompletions -contains "rustup") -and (Get-Command "rustup" -ErrorAction SilentlyContinue)) {
    rustup completions powershell | Out-String | Invoke-Expression
}

# deno emits a very large (~625 KB) completion script; heavy impact on profile load.
if (($NativeCompletions -contains "deno") -and (Get-Command "deno" -ErrorAction SilentlyContinue)) {
    deno completions powershell | Out-String | Invoke-Expression
}

#endregion

#region Command Prompt

function Get-ExecutionTime {
    [OutputType([TimeSpan])]
    param()

    process {
        $History = Get-History
        $ExecTime = $History ? ($History[-1].EndExecutionTime - $History[-1].StartExecutionTime) : (New-TimeSpan)
        Write-Output $ExecTime
    }
}

function prompt {
    $ExecTime = Get-ExecutionTime
    git rev-parse --is-inside-work-tree *> $null

    $GitInfo = if ($LASTEXITCODE -eq 0) {
        $CurrentBranch = git branch --show-current
        $DefaultBranch = (git rev-parse --abbrev-ref origin/HEAD 2>$null) -replace "^origin/", [string]::Empty

        # origin/HEAD is not populated in every clone; fall back to the conventional default branch
        if (!$DefaultBranch) {
            $DefaultBranch = @("main","master") | Where-Object {
                git show-ref --quiet --verify "refs/heads/$_"; $LASTEXITCODE -eq 0
            } | Select-Object -First 1
        }

        # Name of branch takes precedence over any Git tag if not positioned on the default branch
        $Tag = if ($CurrentBranch -and $CurrentBranch -eq $DefaultBranch) { git tag --points-at HEAD }
        $Head = $Tag ?? $CurrentBranch ?? (git rev-parse --short HEAD)
        $DisplayUserName = $SettingsFile.Prompt.EnableGitUserName -eq $true

        #                          U        @     H
        [string]::Format(" {2}({0}{1}{2}{3}{4}{2}{5}){6}",
            $PSStyle.Foreground.Cyan,                                      # 0
            $DisplayUserName ? (git config user.name) : [string]::Empty,   # 1
            $PSStyle.Foreground.Blue,                                      # 2
            $PSStyle.Foreground.BrightBlue,                                # 3
            $DisplayUserName ? "@" : [string]::Empty,                      # 4
            $Head,                                                         # 5
            $PSStyle.Foreground.White                                      # 6
        )
    }

    $CWD = [DirectoryInfo]::new($ExecutionContext.SessionState.Path.CurrentLocation)
    $WindowTitle = $CWD.FullName.Replace($HOME, "~", [StringComparison]::OrdinalIgnoreCase)

    if ($IsWindows) {
        $WindowTitle = $WindowTitle.Replace([Environment]::SystemDirectory, "#", [StringComparison]::OrdinalIgnoreCase)
    }

    $Host.UI.RawUI.WindowTitle = $WindowTitle

    $Battery = if ($SettingsFile.Prompt.EnableBatteryStatus -eq $true) {
        Get-Battery -ErrorAction SilentlyContinue
    }

    $PsPrompt = [StringBuilder]::new()
    $null = & {
        # [username@hostname pwd]
        $PsPrompt.Append("[")
        $PsPrompt.Append($PSStyle.Foreground.BrightCyan)
        $PsPrompt.Append([Environment]::UserName)
        $PsPrompt.Append($PSStyle.Foreground.White)
        $PsPrompt.Append("@")
        $PsPrompt.Append([Environment]::MachineName)
        $PsPrompt.Append(" ")
        $PsPrompt.Append($PSStyle.Foreground.Green)
        $PsPrompt.Append($CWD.BaseName)
        $PsPrompt.Append($PSStyle.Foreground.White)
        $PsPrompt.Append("]")
        $PsPrompt.Append(" ")
        # [ddd%]
        if ($null -ne $Battery -and !$Battery.Status.StartsWith("Connected")) {
            $PsPrompt.Append($PSStyle.Foreground.White)
            $PsPrompt.Append("[")
            $ChargeColor = switch ($Battery.ChargeRemaining) {
                { $_ -ge 70 -and $_ -le 100 } {
                    $PSStyle.Foreground.Green
                }
                { $_ -ge 30 -and $_ -le 69 } {
                    $PSStyle.Foreground.Yellow
                }
                { $_ -ge 0 -and $_ -le 29 } {
                    $PSStyle.Foreground.Red
                }
                default {
                    $PSStyle.Foreground.White
                }
            }
            $PsPrompt.Append($ChargeColor)
            $PsPrompt.Append($Battery.ChargeRemaining)
            $PsPrompt.Append("%")
            $PsPrompt.Append($PSStyle.Foreground.White)
            $PsPrompt.Append("]")
            $PsPrompt.Append(" ")
        }
        # (HH:mm:ss:ms)
        $PsPrompt.Append($PSStyle.Foreground.Yellow)
        $PsPrompt.Append("(")
        $PsPrompt.Append($ExecTime.Hours.ToString("D2"))
        $PsPrompt.Append(":")
        $PsPrompt.Append($ExecTime.Minutes.ToString("D2"))
        $PsPrompt.Append(":")
        $PsPrompt.Append($ExecTime.Seconds.ToString("D2"))
        $PsPrompt.Append(":")
        $PsPrompt.Append($ExecTime.Milliseconds.ToString("D3"))
        $PsPrompt.Append(")")
        $PsPrompt.Append($PSStyle.Foreground.White)
        # (HH:mm:ss)
        if ($SettingsFile.Prompt.EnableTimestamp -eq $true) {
            $PsPrompt.Append(" ")
            $PsPrompt.Append($PSStyle.Foreground.BrightBlack)
            $PsPrompt.Append("(")
            $PsPrompt.Append([DateTime]::Now.ToString("HH:mm:ss"))
            $PsPrompt.Append(")")
            $PsPrompt.Append($PSStyle.Foreground.White)
        }
        # (user@branch)
        $PsPrompt.Append($GitInfo)
        # (active)
        if ($env:VIRTUAL_ENV) {
            $PsPrompt.Append($PSStyle.Foreground.Magenta)
            $PsPrompt.Append([Path]::GetFileName($env:VIRTUAL_ENV))
            $PsPrompt.Append($PSStyle.Foreground.White)
        }
        # #/>
        $PsPrompt.Append([Environment]::NewLine)
        $PsPrompt.Append([string]::new($global:IsAdmin ? "#" : ">", $NestedPromptLevel + 1))
        $PsPrompt.Append(" ")
    }

    return $PsPrompt.ToString()
}

#endregion
