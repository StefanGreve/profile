using namespace System.IO

function Install-Font {
    <#
        .SYNOPSIS
        Installs one or more font files on Windows.

        .DESCRIPTION
        Copies the specified font files into the fonts directory of the selected
        scope, registers them in the corresponding registry key, and notifies
        running applications so the fonts become available without a sign-out.

        The User scope installs for the current user only and does not require
        elevation. The Machine scope installs for all users and requires an
        elevated (administrator) session.

        .PARAMETER Path
        One or more paths to font files to install. Supports wildcards and accepts
        pipeline input from Get-ChildItem. Supported extensions are .ttf, .ttc,
        .otf, and .fon.

        .PARAMETER Scope
        Specifies the installation scope. User (the default) installs for the current
        user without elevation; Machine installs for all users and requires an
        elevated session.

        .INPUTS
        System.String[]. You can pipe font file paths to Install-Font.

        .OUTPUTS
        None. This function does not produce any output.

        .EXAMPLE
        PS> Install-Font -Path ./CascadiaCode.ttf

        Installs a single font for the current user.

        .EXAMPLE
        PS> Get-ChildItem ./fonts -Filter *.otf | Install-Font -Scope Machine

        Installs every OpenType font in the fonts directory for all users. Requires
        an elevated session.

        .LINK
        https://learn.microsoft.com/en-us/windows/win32/gdi/font-and-text-functions
    #>
    [OutputType([void])]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("FullName", "PSPath")]
        [string[]] $Path,

        [Parameter(Position = 1)]
        [ValidateSet("User", "Machine")]
        [string] $Scope = "User"
    )

    begin {
        # ".fon" is a raster format and, unlike the scalable formats, carries no registry type suffix.
        $SuffixMap = @{
            ".ttf" = "(TrueType)"
            ".ttc" = "(TrueType)"
            ".otf" = "(OpenType)"
            ".fon" = ""
        }

        if ($IsWindows) {
            if ($Scope -eq "Machine" -and !(Test-Elevation)) {
                Write-Error "Installing fonts in the Machine scope requires an elevated (administrator) session." `
                    -Category PermissionDenied `
                    -ErrorAction Stop
            }

            Add-Type -AssemblyName System.Drawing

            # Native calls to load the font into the current session and to broadcast the change to running windows.
            if (!("PowerTools.NativeFonts" -as [Type])) {
                Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace PowerTools {
    public static class NativeFonts {
        [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
        public static extern int AddFontResourceW(string lpFileName);
        [DllImport("user32.dll")]
        public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
    }
}
"@
            }

            if ($Scope -eq "Machine") {
                $FontDirectory = [Path]::Join($env:windir, "Fonts")
                $RegistryKey = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
            } else {
                $FontDirectory = [Path]::Join($env:LOCALAPPDATA, "Microsoft", "Windows", "Fonts")
                $RegistryKey = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
            }

            if (!(Test-Path -LiteralPath $FontDirectory)) {
                New-Item -Path $FontDirectory -ItemType Directory -Force | Out-Null
            }
        }
    }
    process {
        if ($IsWindows) {
            foreach ($Item in Resolve-Path -Path $Path) {
                $Source = $Item.ProviderPath
                $Extension = [Path]::GetExtension($Source).ToLowerInvariant()

                if (!$SuffixMap.ContainsKey($Extension)) {
                    Write-Error "'$Source' is not a supported font file ($($SuffixMap.Keys -join ', '))." `
                        -Category InvalidData
                    continue
                }

                $FontNames = @()
                $Collection = [System.Drawing.Text.PrivateFontCollection]::new()

                try {
                    # A single file (notably a .ttc collection) can hold more than one family.
                    $Collection.AddFontFile($Source)
                    $FontNames = @($Collection.Families.Name | Select-Object -Unique)
                } catch {
                    Write-Warning "Could not read the font name from '$Source'."
                } finally {
                    $Collection.Dispose()
                }

                # Raster (.fon) fonts expose no families, and a malformed file may yield none either; fall back to the file name.
                if ($FontNames.Count -eq 0) {
                    $FontNames = @([Path]::GetFileNameWithoutExtension($Source))
                }

                # Windows registers all families in a file under one value name, joined by " & ".
                $FontName = $FontNames -join " & "
                $ValueName = "$FontName $($SuffixMap[$Extension])".Trim()
                $Destination = [Path]::Join($FontDirectory, [Path]::GetFileName($Source))

                if ($PSCmdlet.ShouldProcess($Destination, "Install font `"$FontName`"")) {
                    Copy-Item -LiteralPath $Source -Destination $Destination -Force
                    [PowerTools.NativeFonts]::AddFontResourceW($Destination) | Out-Null

                    # Machine-scope fonts live in the system directory and register by file name; per-user fonts register by full path.
                    $RegistryValue = $Scope -eq "Machine" ? [Path]::GetFileName($Destination) : $Destination
                    New-ItemProperty -Path $RegistryKey -Name $ValueName -Value $RegistryValue -PropertyType String -Force | Out-Null

                    Write-Verbose "Installed '$FontName' to '$Destination' ($Scope scope)."
                }
            }
        } elseif ($IsLinux) {
            Write-Error $OperatingSystemNotSupportedError `
                -Category NotImplemented `
                -ErrorAction Stop
        } elseif ($IsMacOS) {
            Write-Error $OperatingSystemNotSupportedError `
                -Category NotImplemented `
                -ErrorAction Stop
        } else {
            Write-Error $OperatingSystemNotSupportedError `
                -Category NotImplemented `
                -ErrorAction Stop
        }
    }
    end {
        if ($IsWindows) {
            # Notify running applications that the font table changed (WM_FONTCHANGE broadcast).
            $HwndBroadcast = [IntPtr]0xffff
            $WmFontChange = 0x001D
            $SmtoAbortIfHung = 0x0002
            $Result = [IntPtr]::Zero
            [PowerTools.NativeFonts]::SendMessageTimeout($HwndBroadcast, $WmFontChange, [IntPtr]::Zero, [IntPtr]::Zero, $SmtoAbortIfHung, 1000, [ref]$Result) | Out-Null
        }
    }
}
