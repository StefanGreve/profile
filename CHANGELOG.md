# Changelog

## Version 3.0.1 (Unreleased)

### Changed

- `Invoke-XKCD -Download` now skips existing files with a warning instead of overwriting them; pass
  `-Force` to overwrite. The `-Force` switch was previously declared and documented but had no effect.
- `Invoke-TextToSpeech` now caches the installed-voice list for the session instead of constructing a
  `SpeechSynthesizer` on every invocation, reducing parameter-binding and tab-completion overhead.

### Fixed

- `Invoke-TextToSpeech` now works on Windows. The `Voice` dynamic parameter was never bound to a
  `$Voice` variable, so the `begin` block threw under `Set-StrictMode -Version 3.0` before any speech;
  it now reads the value from `$PSBoundParameters`.

- Removed stale references to the former `Toolbox` module name and hardened the build
  script to exclude these entries reliably.
- Corrected the comment-based help across several public Cmdlets to match their implementation.
- `Get-MaxPathLength` now returns an `Int32` on Linux and macOS instead of the raw `getconf` string.
- `Get-Salt` now returns a `System.Byte[]` as documented, instead of an enumerated `Object[]`.
- `Get-FileSize` now always returns a `System.Double`; the default `B` unit and any exact conversion
  previously returned an `Int64`.
- `Set-MonitorBrightness` now actually changes the brightness. It invoked the WMI method directly on a
  `CimInstance` (which exposes no callable methods), so every call failed and reported a misleading
  unsupported-hardware error; it now uses `Invoke-CimMethod`.
- `Set-PowerState` no longer emits the `Boolean` returned by `SetSuspendState` to the pipeline.
- `Set-SystemTheme` no longer emits the value echoed by `osascript` to the pipeline on macOS, so its
  `void` output contract holds on all platforms.

## Version 3.0.0 (22 Aug 2026)

This release expands the module with new Cmdlets and broader platform support,
along with documentation, test coverage, and various fixes to existing functionality.

### Added

- `Install-Font` Cmdlet to install fonts on Windows in the User or Machine scope.
- `Test-Elevation` Cmdlet to check for an elevated (administrator on Windows, root on
  Linux and macOS) session.
- `Invoke-TextToSpeech` Cmdlet.
- PEM certificate import with optional private key in `Install-Certificate`.
- `Get-Battery` and `Set-SystemTheme` support on macOS.
- Unit tests for the environment-variable functions, `Get-MaxPathLength`,
  `Get-StringHash`, `Get-FileSize`, and `Get-FileCount`.
- Comment-based help across the public Cmdlets.

### Changed

- `Stop-LocalServer` now terminates every owning process and runs cross-platform.
- `Set-EnvironmentVariable` now always skips duplicate values with a warning; the
  `-Force` flag that re-added them has been removed.
- `Get-EnvironmentVariable`, `Set-EnvironmentVariable`, and `Remove-EnvironmentVariable`
  now warn and skip on Linux and macOS when a non-Process scope is requested, since
  .NET only supports the Process scope on those platforms.
- `Get-Definition` now resolves aliases to their underlying command before printing the
  definition.
- `Get-StringHash` accepts the hash algorithm as a validated string (`MD5`, `SHA1`,
  `SHA256`, `SHA384`, `SHA512`), which enables tab completion; the default remains `SHA256`.
- `Export-Branch` now verifies the current directory is inside a Git repository before
  running, and its shutdown countdown works cross-platform.
- `Start-Timer` now throttles its progress loop instead of updating continuously.
- Standardized `Write-Error` usage, attribute ordering, and `CmdletBinding` across
  public functions.

### Fixed

- Inconsistent OS detection.
- `Get-Battery` charging detection and unreachable output.
- `-Random` range and per-comic error handling in `Invoke-XKCD`.
- Empty and undefined guards in `Get-EnvironmentVariable`.
- `Set-PowerState` referenced an undefined variable on Linux and macOS, so the requested
  power state was never applied.
- `Export-Branch` passed a non-existent parameter to `Get-Salt`.
- `Get-FileSize` now skips directories with a non-terminating error instead of returning
  a size for them.
- `Set-MonitorBrightness` now disposes the WMI object safely when the display does not
  support software brightness control.

### Removed

- `New-Shortcut`, `Copy-FilePath`, and `Test-Command` Cmdlets. Use the built-in
  `Get-Command -ErrorAction SilentlyContinue` in place of `Test-Command`.
- `Restart-GpgAgent` Cmdlet, which now lives in the configuration repository instead.

## Version 2.0.0 (30 Nov 2024)

First released version on
[PSGallery](https://www.powershellgallery.com/packages/PowerTools/)
with many breaking changes. While this release is stable, the tooling around
creating the module might need some further adjustments. Additionally, a lot of
documentation still needs to be written.
