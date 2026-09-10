# PowerShell Profile

[![Unit Test](https://github.com/StefanGreve/profile/actions/workflows/unit-tests.yml/badge.svg)](https://github.com/StefanGreve/profile/actions/workflows/unit-tests.yml)
[![Publish Module](https://github.com/StefanGreve/profile/actions/workflows/publish-module.yml/badge.svg)](https://github.com/StefanGreve/profile/actions/workflows/publish-module.yml)
![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/powertools?label=PSGallery%20Version)
![PowerShell Version](https://img.shields.io/badge/PowerShell_Version-7.4-blue)
![GitHub License](https://img.shields.io/github/license/stefangreve/profile)

The project contains the source code of my PowerShell profile as well as the
`PowerTools` module. You need version 7.4 or higher to use this project.

The profile and the module ship independently: `profile.ps1` is installed straight
from this repository and picks up changes as soon as they land here, whereas
`PowerTools` follows its own versioned release schedule on the PowerShell Gallery.

## Setup

Run [`install.ps1`](./install.ps1) as _administrator_ to download `profile.ps1`,
symlink it to your selected `$PROFILE`, and install the `PowerTools` module
(which provides the remaining scripts):

```powershell
irm "https://raw.githubusercontent.com/StefanGreve/profile/master/install.ps1" | iex
```

> [!TIP]
> Set your `ExecutionPolicy` to `Unrestricted` in order to run the installer
> script. Note that this configuration step only applies to Windows users.
> On non-Windows computers, `Unrestricted` is already the default `ExecutionPolicy`
> and cannot be changed (see also:
> [About Execution Policy](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.4#long-description))
>
> ```pwsh
> Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted
> ```

## Settings Documentation

The profile reads its configuration from a `profile.config.json` file that lives next to
`profile.ps1` (`install.ps1` downloads a default copy for you). Edit that file to
customize the profile; documentation for the configuration options is provided in
the form of a JSON schema file.

```json
{
    "$schema": "https://raw.githubusercontent.com/StefanGreve/profile/master/profile.config.schema.json",
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
    "RegisterNativeCompletions": [ "gh", "pip", "winget" ]
}
```

> [!WARNING]
> Enabling too many tab completions can degrade profile load performance slightly,
> and the cost varies by program: some emit small completion scripts, while others
> (notably `deno` and `uv`) emit very large ones that noticeably slow profile load.

> [!NOTE]
> To enable tab completion for `dotnet` and .NET-based CLI programs, optionally install the following:
> ```pwsh
> # install an LTS .NET SDK, e.g. version 10
> winget install --id "Microsoft.DotNet.SDK.10"
> dotnet tool install --global "dotnet-suggest"
> ```

> [!TIP]
> The shipped `profile.config.json` references a JSON schema for editor validation and
> completion. Visual Studio Code downloads remote schemas only from trusted domains,
> so add the following to your VS Code `settings.json` (User or Workspace) to allow it:
> ```json
> "json.schemaDownload.trustedDomains": {
>     "https://raw.githubusercontent.com/": true
> }
> ```

## Platform Support

The module targets Windows first, but most Cmdlets run cross-platform. The table below summarizes
which operating systems each exported Cmdlet supports. Cmdlets that are unsupported on a platform
throw a `NotImplemented` error rather than failing silently. The PowerShell profile (`profile.ps1`)
itself is supported on all major platforms.

| Cmdlet                       | ![Windows](https://custom-icon-badges.demolab.com/badge/Windows-0078D6?logo=windows11&logoColor=white) | ![macOS](https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=F0F0F0&logoSize=auto) | ![Linux](https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=black) |
| ---------------------------- | :--------: | :------: | :------: |
| `Get-Battery`                | ✅         | ✅       | ❌       |
| `Get-Definition`             | ✅         | ✅       | ✅       |
| `Get-EnvironmentVariable`    | ✅         | ⚠️       | ⚠️       |
| `Get-FileCount`              | ✅         | ✅       | ✅       |
| `Get-FileSize`               | ✅         | ✅       | ✅       |
| `Get-MaxPathLength`          | ✅         | ✅       | ✅       |
| `Get-RandomPassword`         | ✅         | ✅       | ✅       |
| `Get-Salt`                   | ✅         | ✅       | ✅       |
| `Get-StringHash`             | ✅         | ✅       | ✅       |
| `Install-Certificate`        | ✅         | ❌       | ❌       |
| `Install-Font`               | ✅         | ✅       | ❌       |
| `Invoke-TextToSpeech`        | ✅         | ❌       | ❌       |
| `Invoke-XKCD`                | ✅         | ✅       | ✅       |
| `Remove-EnvironmentVariable` | ✅         | ⚠️       | ⚠️       |
| `Set-EnvironmentVariable`    | ✅         | ⚠️       | ⚠️       |
| `Set-MonitorBrightness`      | ✅         | ✅       | ❌       |
| `Set-PowerState`             | ✅         | ✅       | ✅       |
| `Set-SystemTheme`            | ✅         | ✅       | ❌       |
| `Start-Timer`                | ✅         | ✅       | ✅       |
| `Stop-LocalServer`           | ✅         | ✅       | ✅       |
| `Test-Elevation`             | ✅         | ✅       | ✅       |

> [!WARNING]
> Some Cmdlets offer only partial support on certain platforms: they run but with reduced functionality
> or platform-specific limitations.

## Developer Notes

Set up the development environment. This restores the local .NET tools and installs the
[Husky Git](https://alirezanet.github.io/Husky.Net/)
hooks:

```pwsh
./scripts/init.ps1
```

Use the `dev.ps1` script to build and load a local development version of the
`PowerTools` module. It unloads the currently installed module, builds a local
`0.0.0` version, and re-imports it from source.

```pwsh
./scripts/dev.ps1
```

New releases are published to the PowerShell Gallery by the `Publish Module`
GitHub Actions workflow, which takes the version number as an input.

Run the unit tests with the `test.ps1` script. Pass `-Build` to rebuild the module
before the test run.

```pwsh
./scripts/test.ps1 -Build
```

See also
[`Types.ps1xml` and `Format.ps1xml` files](https://code.visualstudio.com/docs/languages/powershell#_typesps1xml-and-formatps1xml-files)
for editing `ps1xml` files.
