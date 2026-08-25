using namespace System.Collections.ObjectModel
using namespace System.Management.Automation

function Invoke-TextToSpeech {
    <#
        .SYNOPSIS
        Converts text into spoken audio using speech synthesis.

        .DESCRIPTION
        Speaks the supplied message out loud using the System.Speech synthesizer.
        The speaking rate and volume can be adjusted, and on Windows a specific
        installed voice can be selected. This function is only supported on Windows.

        .PARAMETER Message
        Specifies the text to be spoken. This value can be piped to the function.

        .PARAMETER Rate
        Specifies the speaking rate. The value must be between -10 (slowest) and
        10 (fastest). The default rate is 0.

        .PARAMETER Volume
        Specifies the output volume as a percentage. The value must be between 0
        (silent) and 100 (loudest). The default volume is 60.

        .PARAMETER Voice
        Specifies the voice used for speech synthesis. This dynamic parameter is
        only available on Windows and is validated against the set of installed
        voices. If omitted, the default system voice is used.

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
        [int] $Volume = 60
    )

    dynamicparam {
        $ParameterDictionary = [RuntimeDefinedParameterDictionary]::new()

        if ($IsWindows) {
            $VoiceAttribute = [ParameterAttribute]::new()
            $VoiceAttribute.HelpMessage = "Specifies the voice used for speech synthesis."

            $AttributeCollection = [Collection[Attribute]]::new()
            $AttributeCollection.Add($VoiceAttribute)

            $Voices = Get-Variable -Name InstalledVoices -Scope Script -ValueOnly -ErrorAction Ignore

            if ($null -eq $Voices) {
                Add-Type -AssemblyName System.Speech
                $SpeechSynthesizer = New-Object -TypeName System.Speech.Synthesis.SpeechSynthesizer
                $Voices = [string[]]$SpeechSynthesizer.GetInstalledVoices().VoiceInfo.Name
                $SpeechSynthesizer.Dispose()

                Set-Variable -Name InstalledVoices -Scope Script -Value $Voices
            }

            $ValidateSetAttribute = [ValidateSetAttribute]::new($Voices)
            $AttributeCollection.Add($ValidateSetAttribute)

            $ParameterName = "Voice"
            $VoiceParameter = [RuntimeDefinedParameter]::new($ParameterName, [string], $AttributeCollection)
            $ParameterDictionary.Add($ParameterName, $VoiceParameter)
        }

        return $ParameterDictionary
    }

    begin {
        if (!$IsWindows) {
            Write-Error $OperatingSystemNotSupportedError `
                -Category NotImplemented `
                -ErrorAction Stop
        }

        Add-Type -AssemblyName System.Speech
        $SpeechSynthesizer = New-Object -TypeName System.Speech.Synthesis.SpeechSynthesizer
        $Voice = $PSBoundParameters['Voice']

        if (![string]::IsNullOrEmpty($Voice)) {
            $SpeechSynthesizer.SelectVoice($Voice)
        }

        $SpeechSynthesizer.Rate = $Rate
        $SpeechSynthesizer.Volume = $Volume
    }

    process {
        # Prime the audio device with a short pause so its start-up latency does not
        # clip the first word of the utterance.
        $Prompt = New-Object -TypeName System.Speech.Synthesis.PromptBuilder
        $Prompt.AppendBreak([System.Speech.Synthesis.PromptBreak]::Small)
        $Prompt.AppendText($Message)
        $SpeechSynthesizer.Speak($Prompt)
    }

    clean {
        $SpeechSynthesizer.Dispose()
    }
}
