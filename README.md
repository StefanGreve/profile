# PowerShell Core Profile

## Setup

```powershell
git clone git@github.com:StefanGreve/profile.git

# recommended profile path: CurrentUserAllHosts
$PROFILE | Get-Member -Type NoteProperty | Format-List

# create a new symbolic link and dot-source profile.ps1
$ProfilePath = $HOME\Documents\PowerShell\profile.ps1
New-Item -ItemType SymbolicLink -Path $ProfilePath -Value .\profile\profile.ps1
. $Path
```

## Related Repositories

- https://github.com/StefanGreve/confiles
- https://github.com/Advanced-Systems/repomanager
