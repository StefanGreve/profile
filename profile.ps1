using namespace System
using namespace System.IO
using namespace System.Security
using namespace System.Text

using namespace Microsoft.PowerShell

[CultureInfo]::CurrentCulture = [CultureInfo]::CreateSpecificCulture("en-US")
$PSDefaultParameterValues["*:Encoding"] = "utf8"

$PSStyle.Progress.View = "Classic"
$Host.PrivateData.ProgressBackgroundColor = "Cyan"
$Host.PrivateData.ProgressForegroundColor = "Yellow"
$ErrorView = "ConciseView"

$global:IsAdmin = if ($IsWindows) {
    $CurrentUser = [Principal.WindowsPrincipal][Principal.WindowsIdentity]::GetCurrent()
    $Administrator = [Principal.WindowsBuiltInRole]::Administrator
    $CurrentUser.IsInRole($Administrator)
} elseif ($IsLinux) {
    $(id -u) -eq 0
} elseif ($IsMacOS) {
    $(sudo -n true 2>$null) -eq $true
} else {
    $null
}

if ($IsWindows) {
    $global:Natural = { [Regex]::Replace($_.Name, "\d+", { $Args[0].Value.PadLeft(20) }) }
}

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

#region Hook Scripts

if ($env:PROFILE_LOAD_CUSTOM_SCRIPTS -and $(Test-Path $env:PROFILE_LOAD_CUSTOM_SCRIPTS)) {
    Get-ChildItem -Path $env:PROFILE_LOAD_CUSTOM_SCRIPTS -Filter "*.ps1" | ForEach-Object {
        . $_.FullName
    }
}

#endregion

#region Command Prompt

function Start-DailyTranscript {
    [Alias("transcript")]
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [string] $OutputDirectory = [Environment]::GetFolderPath("MyDocuments")
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
    [OutputType([TimeSpan])]
    param()

    process {
        $History = Get-History
        $ExecTime = $History ? ($History[-1].EndExecutionTime - $History[-1].StartExecutionTime) : (New-TimeSpan)
        Write-Output $ExecTime
    }
}

#region Automatically Executing Scripts

if (Get-Module PowerTools) {
    Import-Module PowerTools
}

# Required by Python for custom virtual environment status indicator in prompt function
$env:VIRTUAL_ENV_DISABLE_PROMPT = 1

Start-DailyTranscript | Out-Null

#endregion

function prompt {
    $ExecTime = Get-ExecutionTime

    $GitStatus = if ($(git rev-parse --is-inside-work-tree 2>&1) -eq $true) {
          #        tag                           branch                         detached head
          $Head = (git tag --points-at HEAD) ?? (git branch --show-current) ?? (git rev-parse --short HEAD)
          $DisplayUserName = $env:PROFILE_ENABLE_BRANCH_USERNAME -eq 1

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

    $PythonVirtualEnvironment = if ($env:VIRTUAL_ENV) {
        [string]::Format(" {0}({1}){2}",
            $PSStyle.Foreground.Magenta,
            [Path]::GetFileName($env:VIRTUAL_ENV),
            $PSStyle.Foreground.White
        )
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
        $PsPrompt.Append([DirectoryInfo]::new($ExecutionContext.SessionState.Path.CurrentLocation).BaseName)
        $PsPrompt.Append($PSStyle.Foreground.White)
        $PsPrompt.Append("]")
        $PsPrompt.Append(" ")
        # (HH:mm:ss:ms)
        $PsPrompt.Append($PSStyle.Foreground.Yellow)
        $PsPrompt.Append("(")
        $PsPrompt.Append($ExecTime.Hours.ToString("D2"))
        $PsPrompt.Append(":")
        $PsPrompt.Append($ExecTime.Minutes.ToString("D2"))
        $PsPrompt.Append(":")
        $PsPrompt.Append($ExecTime.Seconds.ToString("D2"))
        $PsPrompt.Append(":")
        $PsPrompt.Append($ExecTime.Milliseconds.ToString("D2"))
        $PsPrompt.Append(")")
        $PsPrompt.Append($PSStyle.Foreground.White)
        # (user@branch)
        $PsPrompt.Append($GitStatus)
        # (active)
        $PsPrompt.Append($PythonVirtualEnvironment)
        # #/>
        $PsPrompt.Append([Environment]::NewLine)
        $PsPrompt.Append([string]::new($global:IsAdmin ? "#" : ">", $NestedPromptLevel + 1))
        $PsPrompt.Append(" ")
    }

    return $PsPrompt.ToString()
}

#endregion
