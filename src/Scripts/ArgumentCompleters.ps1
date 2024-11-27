using namespace System
using namespace System.Management.Automation

#region Environment Variable Completer

$EnvironmentVariableKeyCompleter = {
    param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParameters)

    $Scope = $FakeBoundParameters.ContainsKey("Scope") ? $FakeBoundParameters.Scope : [EnvironmentVariableTarget]::Process
    [Environment]::GetEnvironmentVariables($Scope).Keys | ForEach-Object { [CompletionResult]::new($_) }
}

@("Get-EnvironmentVariable", "Set-EnvironmentVariable", "Remove-EnvironmentVariable") | ForEach-Object {
    Register-ArgumentCompleter -CommandName $_ -ParameterName Key -ScriptBlock $EnvironmentVariableKeyCompleter
}

#endregion
