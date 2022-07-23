# PowerShell Core Profile

Dependency-free cross-platform PowerShell profile based on version 7.2+.

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

# load profile with $psrc after successful bootstrapping
. $ProfilePath
```

## Related Repositories

- https://github.com/StefanGreve/confiles
- https://github.com/Advanced-Systems/repomanager
