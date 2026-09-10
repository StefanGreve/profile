# Changelog

## Version 3.0.1 (Unreleased)

### Added

- `Set-MonitorBrightness` supports macOS. It drives the built-in panel through CoreGraphics and the
  DisplayServices framework, both of which ship with the operating system, so no external tooling is
  required. External monitors remain unsupported, because they expect DDC/CI.
- `Install-Font` supports macOS. Fonts are copied to `~/Library/Fonts` (User scope) or
  `/Library/Fonts` (Machine scope), which the operating system activates on its own. The macOS branch
  accepts `.dfont` in addition to `.ttf`, `.ttc` and `.otf`, and rejects the Windows-only `.fon`
  raster format.

### Changed

- `Invoke-XKCD -Download` skips existing files with a warning unless `-Force` is passed; `-Force`
  previously had no effect.
- `Invoke-TextToSpeech` caches the installed-voice list per session instead of building a
  `SpeechSynthesizer` on every call.
- `Set-MonitorBrightness -Brightness` is now mandatory, so a bare call no longer defaults to `0` and
  blanks the screen.
- `Get-Definition`, `Stop-LocalServer`, `Get-EnvironmentVariable`, and `Install-Certificate` accept
  their primary input from the pipeline (`Install-Certificate -FilePath` also by property name). Their
  per-item errors are now non-terminating; pass `-ErrorAction Stop` to halt on the first failure.
- Hardened parameter validation: `Invoke-XKCD -Last` requires at least `1`, and the `-Path` parameters
  of `Get-FileCount`, `Get-FileSize`, `Install-Font`, and `Invoke-XKCD` reject null or empty values.
- `Get-Battery` reports a missing battery (e.g. on a desktop) and an unsupported operating system as
  non-terminating errors that honor the caller's `-ErrorAction`, instead of always throwing; pass
  `-ErrorAction Stop` to halt.
- Standardized error reporting across the module: terminating errors now use
  `$PSCmdlet.ThrowTerminatingError()` with unique error IDs, and non-terminating errors carry
  `-ErrorId` and `-TargetObject`, so failures expose stable, filterable identities.

### Fixed

- `Invoke-TextToSpeech` works on Windows again (the `Voice` parameter is now read from
  `$PSBoundParameters`) and no longer clips the first spoken word.
- `Test-Elevation` reports elevation correctly on macOS by checking for a root user ID (UID 0).
- `Start-Timer` rejects a zero duration (`-Seconds`, `-Minutes`, and `-Hours` require at least `1`) and
  no longer overshoots the requested duration by about a second.
- `Battery` table view colors a full (100%) charge green, matching the list view.
- `Get-FileCount` reports a missing or inaccessible path as a non-terminating error instead of aborting
  the whole command.
- `Get-FileSize` always returns a `System.Double` and guards paths with `Test-Path -LiteralPath`, so a
  missing or wildcard-bearing path no longer yields a bogus size.
- `Invoke-XKCD` distinguishes a 404 (missing comic) from transport and download failures instead of
  labeling every error "A comic with ID=X does not exist."
- `Get-MaxPathLength` returns an `Int32` on Linux and macOS instead of the raw `getconf` string.
- `Get-Salt` returns a `System.Byte[]` as documented instead of an enumerated `Object[]`.
- `Set-MonitorBrightness` actually changes brightness (via `Invoke-CimMethod`) and no longer throws in
  its `finally` cleanup when the WMI query fails.
- `Set-PowerState` no longer emits the `Boolean` from `SetSuspendState` to the pipeline.
- `Set-SystemTheme` no longer emits the `osascript` echo on macOS.
- `Stop-LocalServer` no longer aborts when it fails to stop one process on a port (e.g. without
  sufficient privileges); it reports that failure and continues with the remaining processes.
- Removed stale references to the former `Toolbox` module name and hardened the build script.
- Corrected comment-based help across several public Cmdlets.

### Removed

- `Export-Branch` (`git-fire`) Cmdlet, which now lives in the configuration repository instead.

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
