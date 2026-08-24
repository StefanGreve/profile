# PowerShell Profile

[![Unit Test](https://github.com/StefanGreve/profile/actions/workflows/unit-tests.yml/badge.svg)](https://github.com/StefanGreve/profile/actions/workflows/unit-tests.yml)
[![Publish Module](https://github.com/StefanGreve/profile/actions/workflows/publish-module.yml/badge.svg)](https://github.com/StefanGreve/profile/actions/workflows/publish-module.yml)
![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/powertools?label=PSGallery%20Version)
![](https://img.shields.io/badge/PowerShell_Version-7.4-blue)
![GitHub License](https://img.shields.io/github/license/stefangreve/profile)

The project contains the source code of my PowerShell profile as well as the
`PowerTools` module. You need version 7.4 or higher to use this project.

## Setup

On Windows, run this from an _elevated_ (administrator) PowerShell session; the
script creates a symbolic link, which requires administrator rights.

Run [`install.ps1`](./install.ps1) to download `profile.ps1`, symlink it to your
selected `$PROFILE`, and install the `PowerTools` module (which provides the
remaining scripts):

```powershell
irm "https://raw.githubusercontent.com/StefanGreve/profile/master/install.ps1" | iex
```

See `Get-Help ./install.ps1` for the `-RepositoryPath` and `-ProfileKind` options.

## Configuration

The profile reads its configuration from a `settings.json` file that lives next to
`profile.ps1` (`install.ps1` downloads a default copy for you). Edit that file to
customize the profile:

```json
{
    "DefaultCulture": "en-US",
    "DefaultEncoding": "utf8",
    "DotSourceDirectory": "~/Documents/Scripts",
    "EnableClassicProgressbar": true,
    "Modules": [ "PowerTools" ],
    "Prompt": {
        "EnableBatteryStatus": true,
        "EnableGitUserName": true,
        "EnableTimestamp": true
    },
    "RegisterNativeCompletions": [ "bat", "gh", "pip", "winget" ]
}
```

<details>
<summary>Settings Documentation</summary>

- `DefaultCulture`: Culture used for the session (defaults to `en-US`).
- `DefaultEncoding`: Default `-Encoding` applied to Cmdlets (defaults to `utf8`).
- `DotSourceDirectory`: Directory to dot-source `*.ps1` scripts from on profile
  launch. A warning is emitted when the path does not exist.
- `EnableClassicProgressbar`: Use the classic progress bar (cyan background, yellow
  text) instead of the default minimal view.
- `Modules`: PowerShell module names to import on profile launch. A warning is
  emitted for any module that is not installed.
- `Prompt.EnableBatteryStatus`: Display the remaining battery charge in the prompt
  while running on battery power.
- `Prompt.EnableGitUserName`: Display the active Git user name next to the branch
  name in the console prompt.
- `Prompt.EnableTimestamp`: Display the current wall-clock time (`HH:mm:ss`) next to
  the elapsed execution time.
- `RegisterNativeCompletions`: Native tools to register argument completers for on
  launch, one of `bat`, `delta`, `deno`, `gh`, `op`, `pip`, `rustup`, `uv`, `winget`.
  Each is only registered when also installed.

> [!WARNING]
> Enabling too many tab completions can degrade profile load performance slightly,
> and the cost varies by program: some emit small completion scripts, while others
> (notably `deno` and `uv`) emit very large ones that noticeably slow profile load.

> [!TIP]
> The shipped `settings.json` references a JSON schema for editor validation and
> completion. Visual Studio Code downloads remote schemas only from trusted domains,
> so add the following to your `settings.json` (User or Workspace) to allow it:
> ```json
> "json.schemaDownload.trustedDomains": {
>     "https://aka.ms/": true,
>     "https://raw.githubusercontent.com/": true
> }
> ```

</details>

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
