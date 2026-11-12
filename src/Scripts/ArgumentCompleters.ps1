using namespace System
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

#region Environment Variable Completer

$EnvironmentVariableKeyCompleter = {
    param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParameters)

    $Scope = $FakeBoundParameters.ContainsKey("Scope") ? $FakeBoundParameters.Scope : [EnvironmentVariableTarget]::Process
    [Environment]::GetEnvironmentVariables($Scope).Keys | Where-Object { $_ -like "$WordToComplete*" }
}

@("Get-EnvironmentVariable", "Set-EnvironmentVariable", "Remove-EnvironmentVariable") | ForEach-Object {
    Register-ArgumentCompleter -CommandName $_ -ParameterName Key -ScriptBlock $EnvironmentVariableKeyCompleter
}

#endregion

#region Voice Completer

$VoiceCompleter = {
    param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParameters)

    # This script runs outside the module, so the cached voice list has to be read from within its scope.
    $Module = (Get-Command -Name $Command).Module
    $Pattern = "$($WordToComplete.Trim("'", '"'))*"

    & $Module { Get-InstalledVoice } | Where-Object { $_ -like $Pattern } | ForEach-Object {
        # Names with spaces or parentheses only bind as a single argument when quoted.
        $CompletionText = $_ -match '^[\w-]+$' ? $_ : "'$([CodeGeneration]::EscapeSingleQuotedStringContent($_))'"
        [CompletionResult]::new($CompletionText, $_, [CompletionResultType]::ParameterValue, $_)
    }
}

Register-ArgumentCompleter -CommandName Invoke-TextToSpeech -ParameterName Voice -ScriptBlock $VoiceCompleter

#endregion
