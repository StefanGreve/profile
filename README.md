# PowerShell Profile

PowerShell profile. Requires at least version 7.3.2 or higher.

## Setup

Note that you need administrator rights in order to create symbolic links.

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

## Remarks

Some optional external dependencies may be added over time, although they will never
interfere with the core features of this profile.

<details>
<summary>Additional Features</summary>

### Winfetch

Creates an alias for [`winfetch`](https://github.com/kiedtl/winfetch) as a faster
replacement for `neofetch` on Windows.

```powershell
Install-Script -Name pwshfetch-test-1 -Scope CurrentUser
```

### Export-Icon

Utility function to export SVGs as increasingly larger quadratic PNG files,
requires [`inkscape`](https://inkscape.org/) for the actual image conversion.

### Get-Calendar

Thin wrapper over Python's built-in `calendar` module to pretty print a calendar.
Notice that this Cmdlet does *not* emit a PowerShell object.

</details>
