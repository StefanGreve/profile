# Changelog

## Unreleased

This release rounds out the module into a coherent, documented toolset: every
public Cmdlet now ships comment-based help, the core functions are covered by unit
tests, native tab completion is wired up for common tooling, and macOS gains parity
for the battery and system-theme features.

### Added

- Native tab completion for `dotnet`, `System.CommandLine`, `bat`, `delta`, `deno`, `gh`,
  `op`, `pip`, `rustup`, `uv`, and `winget`.
- `Invoke-TextToSpeech` Cmdlet.
- PEM certificate import with optional private key in `Install-Certificate`.
- `settings.json` configuration file (loaded from next to `profile.ps1`) with
  `DefaultCulture`, `DefaultEncoding`, `DotSourceDirectory`, `EnableClassicProgressbar`,
  `Modules`, `Prompt`, and `RegisterNativeCompletions` toggles, plus a JSON schema for
  editor validation; `install.ps1` downloads a default copy during setup.
- `Modules` setting to import a configurable list of PowerShell modules on profile
  launch, warning about any that are not installed.
- `EnableClassicProgressbar` setting to toggle the classic progress bar view
  (cyan background, yellow text).
- `RegisterNativeCompletions` setting to opt into argument completers for `bat`, `delta`,
  `deno`, `gh`, `op`, `pip`, `rustup`, `uv`, and `winget`.
- Battery charge indicator in the prompt, colored by remaining charge and shown only
  while on battery power (`Prompt.EnableBatteryStatus`).
- Prompt timestamp toggle (`Prompt.EnableTimestamp`).
- `Get-Battery` and `Set-SystemTheme` support on macOS.
- Unit tests for the environment-variable functions, `Get-MaxPathLength`,
  `Get-StringHash`, `Get-FileSize`, and `Get-FileCount`.
- Comment-based help across the public Cmdlets.

### Changed

- Profile configuration moved from environment variables to `settings.json`,
  replacing `PROFILE_LOAD_CUSTOM_SCRIPTS`, `PROFILE_ENABLE_BRANCH_USERNAME`, and
  `PROFILE_ENABLE_TIMESTAMP`.
- Prompt falls back to the conventional default branch when `origin/HEAD` is unset,
  and hides the Git tag when not on the default branch.
- `Stop-LocalServer` now terminates every owning process and runs cross-platform.
- Standardized `Write-Error` usage, attribute ordering, and `CmdletBinding` across
  public functions.

### Fixed

- Inconsistent OS detection.
- `Get-Battery` charging detection and unreachable output.
- `-Random` range and per-comic error handling in `Invoke-XKCD`.
- Empty and undefined guards in `Get-EnvironmentVariable`.
- Machine name display in the prompt.

### Removed

- `New-Shortcut`, `Copy-FilePath`, and `Test-Command` Cmdlets. Use the built-in
  `Get-Command -ErrorAction SilentlyContinue` in place of `Test-Command`.

## Version 2.0.0 (30 Nov 2024)

First released version on
[PSGallery](https://www.powershellgallery.com/packages/PowerTools/)
with many breaking changes. While this release is stable, the tooling around
creating the module might need some further adjustments. Additionally, a lot of
documentation still needs to be written.
