using namespace System.Diagnostics.CodeAnalysis

[SuppressMessage("PSUseDeclaredVarsMoreThanAssignments", "")]
param()

#region Error Messages

$Disclaimer = "To report an issue, use the following link: https://github.com/stefangreve/profile/issues"

$OperatingSystemNotSupportedError = "This Cmdlet is not supported on your current operating system. ${Disclaimer}"
$ParameterOverloadNotImplementedError = "This method invocation is not implemented yet. ${Disclaimer}"

#endregion
