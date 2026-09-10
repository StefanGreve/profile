using namespace System.IO

function Install-Font {
    <#
        .SYNOPSIS
        Installs one or more font files.

        .DESCRIPTION
        Copies the specified font files into the fonts directory of the selected
        scope and makes them available without a sign-out.

        On Windows the fonts are additionally registered in the corresponding registry
        key and running applications are notified of the change. On macOS the copy is
        all that is required, because the operating system activates every font placed
        in its fonts directories on its own.

        The User scope installs for the current user only and does not require
        elevation. The Machine scope installs for all users and requires an
        elevated (administrator) session.

        .PARAMETER Path
        One or more paths to font files to install. Supports wildcards and accepts
        pipeline input from Get-ChildItem. Supported extensions are .ttf, .ttc and
        .otf on both platforms, plus .fon on Windows and .dfont on macOS.

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

        .NOTES
        The fonts directory depends on the platform and the scope. On Windows the User
        scope resolves to %LOCALAPPDATA%\Microsoft\Windows\Fonts and the Machine scope to
        %WINDIR%\Fonts; on macOS they resolve to ~/Library/Fonts and /Library/Fonts.
        Linux is not supported and raises a NotImplemented error.

        Only Windows reports the font family name stored inside the file, because
        System.Drawing is unavailable on other platforms. Elsewhere the file name is
        reported instead.

        .LINK
        https://learn.microsoft.com/en-us/windows/win32/gdi/font-and-text-functions

        .LINK
        https://support.apple.com/guide/font-book/change-font-book-settings-fntbk1004/mac
    #>
    [OutputType([void])]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("FullName", "PSPath")]
        [ValidateNotNullOrEmpty()]
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
            ".fon" = [string]::Empty
        }

        # macOS cannot render the Windows raster format, but reads the Datafork TrueType suitcase.
        $SupportedExtensions = $IsMacOS ? @(".ttf", ".ttc", ".otf", ".dfont") : @(".ttf", ".ttc", ".otf", ".fon")

        if ($IsWindows -or $IsMacOS) {
            if ($Scope -eq "Machine" -and !(Test-Elevation)) {
                $Message = "Installing fonts in the Machine scope requires an elevated (administrator) session."
                $ErrorRecord = New-TerminatingErrorRecord -Message $Message `
                    -Category PermissionDenied -ErrorId "ElevationRequired"
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }

            if ($IsWindows) {
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
            } else {
                # macOS activates every font placed in these directories on its own, so there is no
                # counterpart to the registry entry and the WM_FONTCHANGE broadcast.
                $FontDirectory = $Scope -eq "Machine" ? "/Library/Fonts" : [Path]::Join($HOME, "Library", "Fonts")
            }

            if (!(Test-Path -LiteralPath $FontDirectory)) {
                New-Item -Path $FontDirectory -ItemType Directory -Force | Out-Null
            }
        }
    }
    process {
        if (!$IsWindows -and !$IsMacOS) {
            $ErrorRecord = New-TerminatingErrorRecord -Message $OperatingSystemNotSupportedError -Category NotImplemented -ErrorId "OperatingSystemNotSupported"
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }

        foreach ($Item in Resolve-Path -Path $Path) {
            $Source = $Item.ProviderPath
            $Extension = [Path]::GetExtension($Source).ToLowerInvariant()

            if ($SupportedExtensions -notcontains $Extension) {
                Write-Error "'$Source' is not a supported font file ($($SupportedExtensions -join ', '))." `
                    -Category InvalidData `
                    -ErrorId "UnsupportedFontFile" `
                    -TargetObject $Source
                continue
            }

            # Covers the platforms without a managed font reader, raster (.fon) files that expose no
            # families, and malformed files that yield none either.
            $FontName = [Path]::GetFileNameWithoutExtension($Source)

            if ($IsWindows) {
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

                # Windows registers all families in a file under one value name, joined by " & ".
                if ($FontNames.Count -gt 0) {
                    $FontName = $FontNames -join " & "
                }

                $ValueName = "$FontName $($SuffixMap[$Extension])".Trim()
            }

            $Destination = [Path]::Join($FontDirectory, [Path]::GetFileName($Source))

            if ($PSCmdlet.ShouldProcess($Destination, "Install font `"$FontName`"")) {
                Copy-Item -LiteralPath $Source -Destination $Destination -Force

                if ($IsWindows) {
                    [PowerTools.NativeFonts]::AddFontResourceW($Destination) | Out-Null

                    # Machine-scope fonts live in the system directory and register by file name; per-user fonts register by full path.
                    $RegistryValue = $Scope -eq "Machine" ? [Path]::GetFileName($Destination) : $Destination
                    New-ItemProperty -Path $RegistryKey -Name $ValueName -Value $RegistryValue -PropertyType String -Force | Out-Null
                }

                Write-Verbose "Installed '$FontName' to '$Destination' ($Scope scope)."
            }
        }
    }
    end {
        if ($IsWindows) {
            # WM_FONTCHANGE broadcast settings.
            $HwndBroadcast = [IntPtr]0xffff
            $WmFontChange = 0x001D
            $SmtoAbortIfHung = 0x0002
            $Result = [IntPtr]::Zero

            # Notify running applications that the font table changed.
            [PowerTools.NativeFonts]::SendMessageTimeout(
                $HwndBroadcast,
                $WmFontChange,
                [IntPtr]::Zero,
                [IntPtr]::Zero,
                $SmtoAbortIfHung,
                1000,
                [ref]$Result
            ) | Out-Null
        }
    }
}
