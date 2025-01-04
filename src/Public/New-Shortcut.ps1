using namespace System.IO
using namespace System.Runtime

function New-Shortcut {
    <#
        .SYNOPSIS
        Creates a new shortcut file at the specified location.

        .DESCRIPTION
        Creates a new a shortcut (.lnk) file with the specified parameters.
        The shortcut is created at the given path and points to the specified target.

        .PARAMETER Name
         Specifies the name of the shortcut file (without the file extension).

        .PARAMETER Path
         Specifies the directory where the shortcut file will be created.

        .PARAMETER Target
        Specifies the target of the shortcut. This can be a file, folder, or URL
        that the shortcut will point to.

        .PARAMETER Description
        Specifies an optional description for the shortcut. This description is
        displayed in the shortcut's properties.

        .INPUTS
        None. You can't pipe objects to New-Shortcut.

        .EXAMPLE
        PS> New-Shortcut -Name "MyApp" -Path "C:\Shortcuts" -Target "C:\Program Files\MyApp\MyApp.exe"

        Creates a shortcut named MyApp.lnk in the C:\Shortcuts directory pointing to
        C:\Program Files\MyApp\MyApp.exe.

        .EXAMPLE
        PS> New-Shortcut -Name "WebsiteShortcut" -Path "C:\Shortcuts" -Target "https://example.com" -Description "Shortcut to Example Website"

        Creates a shortcut named WebsiteShortcut.lnk in the C:\Shortcuts directory
        pointing to https://example.com with a description.

        .OUTPUTS
         [FileSystemInfo]. Returns the created shortcut file.
    #>
    [CmdletBinding()]
    [OutputType([FileSystemInfo])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Target,

        [string] $Description
    )

    begin {
        if (!$IsWindows) {
            Write-Error $OperatingSystemNotSupportedError -Category NotImplemented -ErrorAction Stop
        }

        $Shell = New-Object -ComObject WScript.Shell
        $Directory = Resolve-Path $Path
    }
    process {
        $Name = [Path]::ChangeExtension([Path]::Combine($Directory, $Name), ".lnk")

        if ([File]::Exists($Name)) {
            Write-Error -Message "The file \"${Name}\" already exists" -Category ResourceExists -CategoryTargetName $Name -ErrorAction Stop
            return
        }

        $Shortcut = $Shell.CreateShortcut($Name)
        $Shortcut.TargetPath = $Target
        $Shortcut.Description = $Description
        $Shortcut.Save()
        Get-Item -Path $Name
    }
    clean {
        [InteropServices.Marshal]::ReleaseComObject($Shell) | Out-Null
    }
}
