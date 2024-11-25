function Get-MaxPathLength {
    process {
        $MaxPathLength = if ($IsWindows) {
            # On Windows, file names cannot exceed 256 bytes. Starting with Windows 10 (version 1607), the max path
            # limit preference can be configured in the registry (which is a opt-in feature):
            # Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Type DWord -Value 1 -Force
            # https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation
            $FileSystem = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled"
            $FileSystem.LongPathsEnabled -eq 1 ? 32767 : 260
        } elseif ($IsLinux -or $IsMacOS) {
            # On virtually all file systems, file names are restricted to 255 bytes in length (cf. NAME_MAX).
            # PATH_MAX equals 4096 bytes in Unix environments, though Unix can deal with longer file paths by using
            # relative paths or symbolic links. To convert bytes to characters, you need to know the encoding ahead
            # of time. For example, an ASCII or Unicode character in UTF-8 is 8 bits (1 byte), while a Unicode character
            # in UTF-16 may take between 16 bits (2 bytes) and 32 bits (4 bytes) in memory, whereas UTF-32 encoded
            # Unicode characters always require 32 bits (4 bytes) of memory
            getconf PATH_MAX /
        } else {
            Write-Error $OperatingSystemNotSupportedError -Category NotImplemented -ErrorAction Stop
        }

        Write-Output $MaxPathLength
    }
}
