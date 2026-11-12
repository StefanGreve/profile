function Invoke-TextToSpeech {
    <#
        .SYNOPSIS
        Converts text into spoken audio using speech synthesis.

        .DESCRIPTION
        Speaks the supplied message out loud using the System.Speech synthesizer on Windows
        and the say command on macOS. The speaking rate and volume can be adjusted, and a
        specific installed voice can be selected.

        .PARAMETER Message
        Specifies the text to be spoken. This value can be piped to the function.

        .PARAMETER Rate
        Specifies the speaking rate. The value must be between -10 (slowest) and
        10 (fastest). The default rate is 0.

        .PARAMETER Volume
        Specifies the output volume as a percentage. The value must be between 0
        (silent) and 100 (loudest). The default volume is 60.

        .PARAMETER Voice
        Specifies the voice used for speech synthesis. Tab completion lists the installed
        voices, and any other name raises a VoiceNotFound error. On macOS, a voice whose
        name carries its language, such as "Anna (German (Germany))", can also be selected
        by its bare name, which leaves the choice among its variants to say. If omitted,
        the default system voice is used.

        .INPUTS
        System.String. You can pipe the message to be spoken to Invoke-TextToSpeech.

        .OUTPUTS
        None. This function does not produce any output.

        .EXAMPLE
        PS> Invoke-TextToSpeech -Message "Hello, world."

        Speaks the message using the default voice, rate, and volume.

        .EXAMPLE
        PS> "Build complete." | Invoke-TextToSpeech -Rate 2 -Volume 80

        Speaks a piped message slightly faster than normal at 80% volume.

        .EXAMPLE
        PS> Invoke-TextToSpeech -Message "Hallo, Welt." -Voice Anna

        Speaks a German message with the voice Anna on macOS.

        .NOTES
        On macOS, the function invokes the say command that ships with the operating system.
        Because say expects words per minute, -Rate follows the logarithmic SAPI scale around
        the default of 175 words per minute, from a third (-10) to three times (10) that rate.
        -Volume is applied through the embedded speech command [[volm]], and say interprets
        other embedded commands in the message as well, such as [[slnc 500]]. Linux is not
        supported and raises a NotImplemented error.

        On both platforms, every message starts with a short pause, so that the start-up
        latency of the audio device does not clip the first word.

        .LINK
        https://learn.microsoft.com/en-us/dotnet/api/system.speech.synthesis.speechsynthesizer
    #>
    [OutputType([void])]
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Message,

        [ValidateRange(-10, 10)]
        [Parameter()]
        [int] $Rate = 0,

        [ValidateRange(0, 100)]
        [Parameter()]
        [int] $Volume = 60,

        [ValidateNotNullOrEmpty()]
        [Parameter()]
        [string] $Voice
    )

    begin {
        if (!$IsWindows -and !$IsMacOS) {
            $ErrorRecord = New-TerminatingErrorRecord -Message $OperatingSystemNotSupportedError -Category NotImplemented -ErrorId "OperatingSystemNotSupported"
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }

        if ($PSBoundParameters.ContainsKey("Voice")) {
            $InstalledVoices = @(Get-InstalledVoice)

            if ($IsMacOS) {
                # Once several variants of a voice are installed, macOS qualifies each with its language, as in
                # "Anna (German (Germany))". say still resolves the bare name, so that form is accepted as well.
                $InstalledVoices += $InstalledVoices -replace '\s+\(.+\)$'
            }

            # The comparison ignores case, so adopting the installed name also normalizes the casing.
            $InstalledVoice = $InstalledVoices -eq $Voice | Select-Object -First 1

            if ($null -eq $InstalledVoice) {
                $ErrorRecord = New-TerminatingErrorRecord -Message "Voice `"$Voice`" is not installed." `
                    -Category ObjectNotFound -ErrorId "VoiceNotFound" -TargetObject $Voice
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }

            $Voice = $InstalledVoice
        }

        if ($IsWindows) {
            Add-Type -AssemblyName System.Speech
            $SpeechSynthesizer = [System.Speech.Synthesis.SpeechSynthesizer]::new()

            if (![string]::IsNullOrEmpty($Voice)) {
                $SpeechSynthesizer.SelectVoice($Voice)
            }

            $SpeechSynthesizer.Rate = $Rate
            $SpeechSynthesizer.Volume = $Volume
        } else {
            # say expects words per minute. The SAPI scale is logarithmic and spans a third to three times the
            # default rate, which is 175 words per minute for say.
            $DefaultWordsPerMinute = 175
            $WordsPerMinute = [int] ($DefaultWordsPerMinute * [Math]::Pow(3, $Rate / 10))
            $SayArguments = @("-r", $WordsPerMinute)

            if (![string]::IsNullOrEmpty($Voice)) {
                $SayArguments += "-v", $Voice
            }

            # The 500 ms pause matches PromptBreak.Small and is stretched, because say shortens silence at faster rates.
            # Each embedded command needs its own brackets, because say reads a semicolon-separated list aloud.
            $Silence = [Math]::Max(500, [int] (500 * $WordsPerMinute / $DefaultWordsPerMinute))
            $SpeechCommands = "[[volm $($Volume / 100)]][[slnc $Silence]]"
        }
    }

    process {
        if ($IsWindows) {
            # Prime the audio device with a short pause so its start-up latency does not
            # clip the first word of the utterance.
            $Prompt = [System.Speech.Synthesis.PromptBuilder]::new()
            $Prompt.AppendBreak([System.Speech.Synthesis.PromptBreak]::Small)
            $Prompt.AppendText($Message)
            $SpeechSynthesizer.Speak($Prompt)
        } else {
            $Diagnostics = say @SayArguments -- "$SpeechCommands $Message" 2>&1

            if ($LASTEXITCODE -ne 0) {
                # say can follow the reason on its first line with an Objective-C backtrace.
                $Reason = $Diagnostics | Select-Object -First 1
                Write-Error "Failed to speak the message (say exit code ${LASTEXITCODE}). $Reason" `
                    -Category DeviceError `
                    -ErrorId "SpeechSynthesisFailed" `
                    -TargetObject $Message
            }
        }
    }

    clean {
        # begin can terminate before it creates the synthesizer, and strict mode rejects reading unset variables.
        $SpeechSynthesizer = Get-Variable -Name SpeechSynthesizer -Scope Local -ValueOnly -ErrorAction Ignore

        if ($null -ne $SpeechSynthesizer) {
            $SpeechSynthesizer.Dispose()
        }
    }
}
