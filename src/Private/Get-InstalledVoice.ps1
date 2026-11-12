function Get-InstalledVoice {
    <#
        .SYNOPSIS
        Returns the names of the speech synthesis voices installed on this computer.

        .DESCRIPTION
        Enumerates the installed voices once per session and caches the result, because both the
        validation and the tab completion of Invoke-TextToSpeech -Voice need them, and listing them
        through say takes up to a second on macOS.

        .INPUTS
        None. You can't pipe objects to Get-InstalledVoice.

        .OUTPUTS
        System.String. The name of each installed voice; nothing on unsupported platforms.

        .NOTES
        Internal helper; not exported from the module.
    #>
    [OutputType([string])]
    param()

    $Voices = Get-Variable -Name InstalledVoices -Scope Script -ValueOnly -ErrorAction Ignore

    if ($null -eq $Voices) {
        if ($IsWindows) {
            Add-Type -AssemblyName System.Speech
            $SpeechSynthesizer = [System.Speech.Synthesis.SpeechSynthesizer]::new()
            $Voices = [string[]]$SpeechSynthesizer.GetInstalledVoices().VoiceInfo.Name
            $SpeechSynthesizer.Dispose()
        } elseif ($IsMacOS) {
            # Each line reads "<Name> <Locale> # <Sample>", where the name may contain spaces and
            # parentheses, and some voices are listed twice.
            $Voices = [string[]] ((say -v "?") -replace '\s+\S+\s+#.*$' | Select-Object -Unique)
        } else {
            $Voices = [string[]] @()
        }

        Set-Variable -Name InstalledVoices -Scope Script -Value $Voices
    }

    $Voices
}
