# Changelog

## Unreleased

This release rounds out the module into a coherent, documented toolset: every
public Cmdlet now ships comment-based help, the core functions are covered by unit
tests, native tab completion is wired up for common tooling, and macOS gains parity
for the battery and system-theme features.

### Added

- Native tab completion for `dotnet`, `System.CommandLine`, `bat`, `gh`, and `winget`.
- `Invoke-TextToSpeech` Cmdlet.
- PEM certificate import with optional private key in `Install-Certificate`.
- `PROFILE_ENABLE_TIMESTAMP` toggle to display a timestamp in the prompt.
- `Get-Battery` and `Set-SystemTheme` support on macOS.
- Unit tests for the environment-variable functions, `Get-MaxPathLength`,
  `Get-StringHash`, `Get-FileSize`, and `Get-FileCount`.
- Comment-based help across the public Cmdlets.

### Changed

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
