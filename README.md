# PowerShell Profile

PowerShell profile. Requires at least version 7.4 or higher.

## Setup

Note that you need administrator rights in order to create symbolic links on Windows,
unless you have turned on `Developer Mode` in the settings app:

<details>
<summary>Instructions</summary>

```powershell
git clone git@github.com:StefanGreve/profile.git

# Recommended profile path: CurrentUserAllHosts
$PROFILE | Get-Member -Type NoteProperty | Format-List

# Create a PowerShell directory if it doesn't exists already
New-Item "$HOME\Documents\PowerShell" -ItemType Directory -ErrorAction SilentlyContinue

# Create a new symbolic link and dot-source profile.ps1
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

## Developer Notes

Configure development environment:

```powershell
dotnet tool restore
```
