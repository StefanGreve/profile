using namespace System.IO
using namespace System.Runtime

function New-Shortcut {
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
