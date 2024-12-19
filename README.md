# PowerShell Profile

[![Unit Test](https://github.com/StefanGreve/profile/actions/workflows/unit-tests.yml/badge.svg)](https://github.com/StefanGreve/profile/actions/workflows/unit-tests.yml)
[![Publish Module](https://github.com/StefanGreve/profile/actions/workflows/publish-module.yml/badge.svg)](https://github.com/StefanGreve/profile/actions/workflows/publish-module.yml)
![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/powertools?label=PSGallery%20Version)
![](https://img.shields.io/badge/PowerShell_Version-7.4-blue)
![GitHub License](https://img.shields.io/github/license/stefangreve/profile)

The project contains the source code of my PowerShell profile as well as the
`PowerTools` module. You need *at least* version 7.4 or higher to use this project.

## Setup

Note that you need administrator rights in order to create symbolic links on
Windows, unless you have turned on `Developer Mode` in the settings app:

<details>
<summary>Instructions</summary>

```powershell
# Save the PowerShell profile in the current working directory
Invoke-WebRequest -Uri https://raw.githubusercontent.com/StefanGreve/profile/refs/heads/master/profile.ps1 -Out profile.ps1

# Add some additional features to the profile on startup (optional)
Install-Module -Name PowerTools -Force
```

### Windows

```powershell
# Select a profile path (Recommended: CurrentUserAllHosts)
$PROFILE | Get-Member -Type NoteProperty | Format-List

$Definition = $PROFILE
  | Get-Member -Type NoteProperty
  | Where-Object Name -eq CurrentUserAllHosts
  | Select-Object -ExpandProperty Definition

$ProfilePath = $Definition.Split("=")[1]

# Create a PowerShell directory if necessary
New-Item $(Split-Path -Parent $ProfilePath) -ItemType Directory -ErrorAction SilentlyContinue

# Create a new symbolic link
New-Item -Path $ProfilePath -ItemType SymbolicLink -Value $(Resolve-Path profile.ps1).Path
```

### MacOS

```powershell
# Create a new symbolic link
New-Item -Path $PROFILE -ItemType SymbolicLink -Value $(Resolve-Path ./profile.ps1).Value -Force
```

</details>

This profile is also part of the
[`configuration`](https://github.com/stefangreve/configuration)
repository.

## Configuration

Some additional features can be turned on by setting their respective environment
variables:

- `PROFILE_LOAD_CUSTOM_SCRIPTS`: Declare a single path to dot-source Powershell
  scripts from on profile launch.
- `PROFILE_ENABLE_BRANCH_USERNAME`: Set this value to `1` to display the active
  Git user name next to the branch name in the console prompt (off by default)

## Developer Notes

Setup the development environment:

```powershell
dotnet tool restore
```

Set your `ExecutionPolicy` to `Unrestricted` in order to run any of these
scripts. Note that this configuration step only applies to Windows users.
on non-Windows computers, `Unrestricted` is already the default `ExecutionPolicy`
and cannot be changed (see also:
[About Execution Policy](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.4#long-description))

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted
```

Use the `build.ps1` script for creating a new version of the `PowerTools` module.
Remember to unload the module if you have installed it from the PowerShell Gallery.

```powershell
Remove-Module PowerTools

# Local builds should use this version number
./build.ps1 -Version 0.0.0
```

During development, the `Version` number of this module is configured as `0.0.0`.

See also
[`Types.ps1xml` and `Format.ps1xml` files](https://code.visualstudio.com/docs/languages/powershell#_typesps1xml-and-formatps1xml-files)
for editing `ps1xml` files.
