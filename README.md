# PowerShell Core Profile

PowerShell Core profile.

## Setup

Note that you need administrator privileges in order to create symbolic links.

```powershell
# note: initialize as submodule if used in a dotfile repository
git clone git@github.com:StefanGreve/profile.git

# recommended profile path: CurrentUserAllHosts
$PROFILE | Get-Member -Type NoteProperty | Format-List

# create a new symbolic link and dot-source profile.ps1
$ProfilePath = $HOME\Documents\PowerShell\profile.ps1
New-Item -ItemType SymbolicLink -Path $ProfilePath -Target .\profile\profile.ps1
```

## Remarks

Some optional external dependencies may be added over time, although they will never
interfere with the core features of this profile.

<details>
<summary>Additional Features</summary>

## Winfetch

Creates an alias for [`winfetch`](https://github.com/kiedtl/winfetch) as a faster
replacement for `neofetch` on Windows.

```powershell
Install-Script -Name pwshfetch-test-1 -Scope CurrentUser
```

## Export-Icon

Utility function to export SVGs as increasingly larger quadratic PNG files,
requires [`inkscape`](https://inkscape.org/) for the actual image conversion.

## Get-Calendar

Thin wrapper over Python's built-in `calendar` module to pretty print a calendar.
Notice that this Cmdlet does *not* emit a PowerShell object.

</details>

---

## Related Repositories

Other projects you might also be interested into:

- https://github.com/StefanGreve/confiles
- https://github.com/Advanced-Systems/todo
- https://github.com/Advanced-Systems/repomanager
