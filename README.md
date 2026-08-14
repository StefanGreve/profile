# PowerShell Profile

[![Unit Test](https://github.com/StefanGreve/profile/actions/workflows/unit-tests.yml/badge.svg)](https://github.com/StefanGreve/profile/actions/workflows/unit-tests.yml)
[![Publish Module](https://github.com/StefanGreve/profile/actions/workflows/publish-module.yml/badge.svg)](https://github.com/StefanGreve/profile/actions/workflows/publish-module.yml)
![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/powertools?label=PSGallery%20Version)
![](https://img.shields.io/badge/PowerShell_Version-7.4-blue)
![GitHub License](https://img.shields.io/github/license/stefangreve/profile)

The project contains the source code of my PowerShell profile as well as the
`PowerTools` module. You need version 7.4 or higher to use this project.

## Setup

Note that you need administrator rights in order to create symbolic links on
Windows, unless you have turned on `Developer Mode` in the settings app:

<details>
<summary>Instructions</summary>

```powershell
# Get the PowerShell profile repository
git clone https://github.com/StefanGreve/profile.git
$ProfileSource = $(Resolve-Path "./profile/profile.ps1").Path

# Add some additional features to the profile on startup (optional)
Install-Module -Name PowerTools -Force

# Select a profile path (Recommended: CurrentUserAllHosts)
$PROFILE | Get-Member -Type NoteProperty | Format-List
$ProfilePath = $PROFILE.CurrentUserAllHosts

# Create a PowerShell directory if necessary
New-Item $(Split-Path -Parent $ProfilePath) -ItemType Directory -Force

# Create a new symbolic link
New-Item -Path $ProfilePath -ItemType SymbolicLink -Value $ProfileSource -Force
```

</details>

This profile is also part of the
[`configuration`](https://github.com/stefangreve/configuration)
repository.

## Configuration

Some additional features can be turned on by setting their respective environment
variables:

- `PROFILE_LOAD_CUSTOM_SCRIPTS`: Declare a single path to dot-source PowerShell
  scripts from on profile launch.
- `PROFILE_ENABLE_BRANCH_USERNAME`: Set this value to `1` to display the active
  Git user name next to the branch name in the console prompt (off by default).
- `PROFILE_ENABLE_TIMESTAMP`: Set this value to `1` to display the current
  wall-clock time (`HH:mm:ss`) next to the elapsed execution time (off by default).

## Developer Notes

Set up the development environment:

```powershell
dotnet tool restore
dotnet husky install
```

Set your `ExecutionPolicy` to `Unrestricted` in order to run any of these
scripts. Note that this configuration step only applies to Windows users.
On non-Windows computers, `Unrestricted` is already the default `ExecutionPolicy`
and cannot be changed (see also:
[About Execution Policy](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.4#long-description))

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted
```

Use the `dev.ps1` script to build and load a local development version of the
`PowerTools` module. It unloads the currently installed module, builds a local
`0.0.0` version, and re-imports it from source.

```powershell
./scripts/dev.ps1
```

New releases are published to the PowerShell Gallery by the `Publish Module`
GitHub Actions workflow, which takes the version number as an input.

Run the unit tests with the `test.ps1` script. Pass `-Build` to rebuild the module
before the test run.

```powershell
./scripts/test.ps1 -Build
```

See also
[`Types.ps1xml` and `Format.ps1xml` files](https://code.visualstudio.com/docs/languages/powershell#_typesps1xml-and-formatps1xml-files)
for editing `ps1xml` files.
