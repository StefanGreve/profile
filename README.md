# PowerShell Profile

PowerShell profile. Requires at least version 7.3.4 or higher.

## Setup

Note that you need administrator rights in order to create symbolic links on Windows,
unless you have turned on `Developer Mode` in the settings app:

<details>
<summary>Instructions</summary>

```powershell
git clone git@github.com:StefanGreve/profile.git

# recommended profile path: CurrentUserAllHosts
$PROFILE | Get-Member -Type NoteProperty | Format-List

# create a PowerShell directory if it doesn't exists already
New-Item "$HOME\Documents\PowerShell" -ItemType Directory -ErrorAction SilentlyContinue

# create a new symbolic link and dot-source profile.ps1
$ProfilePath = "$HOME\Documents\PowerShell\profile.ps1"
New-Item -Path $ProfilePath -ItemType SymbolicLink -Value $(Resolve-Path profile.ps1).Path
```

</details>

This profile is also part of the
[`configuration`](https://github.com/stefangreve/configuration)
repository.

## Configuration

Some additional features can be turned on by setting their respective environment
variables:

- `PROFILE_ENABLE_DAILY_TRANSCRIPTS`: Set this value to `1` to enable automatic
- transcript storing in `MyDocuments\Transcripts` (off by default)

- `PROFILE_LOAD_CUSTOM_SCRIPTS`: Declare a single path to dot-source Powershell
  scripts from on profile launch.
- `PROFILE_ENABLE_BRANCH_USERNAME`: Set this value to `1` to display the active
  Git user name next to the branch name in the console prompt (off by default)

## Features

<details>
<summary>Content</summary>

### Utilities

- `Get-Battery`
- `Get-Calendar`
- `Set-PowerState`
- `Set-EnvironmentVariable`
- `Get-EnvironmentVariable`
- `Get-WorldClock`
- `Remove-EnvironmentVariable`
- `Restart-GpgAgent`
- `Set-WindowsTheme`*
- `Set-MonitorBrightness`*
- `Start-DailyTranscript`
- `Start-ElevatedConsole`
- `Start-Timer`

### Development

- `Export-Branch`
- `Get-Definition`
- `Get-ExecutionTime`
- `Install-Certificate`
- `Stop-LocalServer`
- `Test-Command`

### File Extensions

- `Copy-FilePath`
- `Export-Icon`
- `Get-FileCount`
- `Get-FileSize`
- `Get-FilePath`
- `Get-MaxPathLength`
- `New-Shortcut`*

### Cryptography

- `Get-Salt`
- `Get-StringHash`
- `Get-RandomPassword`

### Miscellaneous

- `Get-XCKD`

### Enums

- `OS`
- `Month`

</details>

## Remarks

While this script attempts to be as lightweight as possible, a few externals are
required to run some of the Cmdlets from this profile.

<details>
<summary>Third-Party Dependencies</summary>

### `Export-Icon`

Utility function to export SVGs as increasingly larger quadratic PNG files,
requires [`inkscape`](https://inkscape.org/) for the actual image conversion.

### `Get-Definition`

Requires the `bat` cargo for pretty terminal output.

### `Get-Calendar`

Thin wrapper over Python's built-in `calendar` module to pretty print a calendar.
Notice that this Cmdlet does *not* emit a PowerShell object. The behavior of this
Cmdlet is subject to future changes, see also: [Issue #9](https://github.com/StefanGreve/profile/issues/9).

</details>

Also note that some Cmdlets are Windows-exclusive and marked with an asterisk in
the feature list.
