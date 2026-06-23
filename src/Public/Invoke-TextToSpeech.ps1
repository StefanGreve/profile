using namespace System.Collections.ObjectModel
using namespace System.Management.Automation

function Invoke-TextToSpeech {
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Message,

        [ValidateRange(-10, 10)]
        [Parameter(Mandatory = $false)]
        [int] $Rate = 0,

        [ValidateRange(0, 100)]
        [Parameter(Mandatory = $false)]
        [int] $Volume = 60
    )

    dynamicparam {
        $ParameterDictionary = [RuntimeDefinedParameterDictionary]::new()

        if ($IsWindows) {
            $VoiceAttribute = [ParameterAttribute]::new()
            $VoiceAttribute.HelpMessage = "Specifies the voice used for speech synthesis."

            $AttributeCollection = [Collection[Attribute]]::new()
            $AttributeCollection.Add($VoiceAttribute)

            Add-Type -AssemblyName System.Speech
            $SpeechSynthesizer = New-Object -TypeName System.Speech.Synthesis.SpeechSynthesizer
            $Voices = $SpeechSynthesizer.GetInstalledVoices().VoiceInfo.Name
            $SpeechSynthesizer.Dispose()

            $ValidateSetAttribute = [ValidateSetAttribute]::new([string[]]$Voices)
            $AttributeCollection.Add($ValidateSetAttribute)

            $ParameterName = "Voice"
            $VoiceParameter = [RuntimeDefinedParameter]::new($ParameterName, [string], $AttributeCollection)
            $ParameterDictionary.Add($ParameterName, $VoiceParameter)
        }

        return $ParameterDictionary
    }

    begin {
        if (!$IsWindows) {
            Write-Error $OperatingSystemNotSupportedError -Category NotImplemented -ErrorAction Stop
        }

        Add-Type -AssemblyName System.Speech
        $SpeechSynthesizer = New-Object -TypeName System.Speech.Synthesis.SpeechSynthesizer

        if (![string]::IsNullOrEmpty($Voice)) {
            $SpeechSynthesizer.SelectVoice($Voice)
        }

        $SpeechSynthesizer.Rate = $Rate
        $SpeechSynthesizer.Volume = $Volume
    }

    process {
        $SpeechSynthesizer.Speak($Message)
    }
    clean {
        $SpeechSynthesizer.Dispose()
    }
}
