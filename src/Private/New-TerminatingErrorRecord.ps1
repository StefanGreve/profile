using namespace System
using namespace System.Management.Automation

function New-TerminatingErrorRecord {
    <#
        .SYNOPSIS
        Builds an ErrorRecord for use with $PSCmdlet.ThrowTerminatingError().

        .DESCRIPTION
        Centralizes ErrorRecord construction so the module's terminating errors stay
        consistent in category, identifier, and shape. This is an internal helper: it only
        builds the record and returns it, deliberately leaving the throw to the caller.

        Terminating errors must be raised with the calling command's own $PSCmdlet, so that
        PowerShell attributes the error to that command (its name appears in the
        FullyQualifiedErrorId) and terminates it rather than this helper. Each Cmdlet
        therefore passes the returned record to $PSCmdlet.ThrowTerminatingError().

        .PARAMETER Message
        The human-readable description of the failure. It becomes the message of the
        ErrorRecord's exception and is shown to the user.

        .PARAMETER Category
        The ErrorCategory that classifies the failure (for example, NotImplemented,
        ObjectNotFound, or PermissionDenied). It is surfaced in the error's CategoryInfo.

        .PARAMETER ErrorId
        A stable, unique identifier for this error. It is combined with the calling command's
        name to form the FullyQualifiedErrorId, letting callers catch or filter on the error
        independently of the -Message wording. Defaults to the -Category name when omitted;
        prefer an explicit, descriptive value (for example, "OperatingSystemNotSupported").

        .PARAMETER TargetObject
        The object the error is about (the source of the failure), such as a path, a port, or
        a process. It is attached to the ErrorRecord so tooling can inspect the subject of the
        failure without parsing the message text.

        .PARAMETER Exception
        An optional underlying exception, typically the caught error inside a catch block. When
        supplied, it is preserved as the InnerException while -Message provides context, so the
        original error's details are retained. When omitted, a new exception is created from
        -Message alone.

        .INPUTS
        None. You can't pipe objects to New-TerminatingErrorRecord.

        .OUTPUTS
        System.Management.Automation.ErrorRecord. A record ready to pass to
        $PSCmdlet.ThrowTerminatingError().

        .EXAMPLE
        PS> $PSCmdlet.ThrowTerminatingError(
                (New-TerminatingErrorRecord $OperatingSystemNotSupportedError NotImplemented "OperatingSystemNotSupported"))

        Terminates the calling Cmdlet with an error whose FullyQualifiedErrorId is
        "OperatingSystemNotSupported,<CmdletName>".

        .EXAMPLE
        PS> try {
                Invoke-CimMethod -InputObject $WmiMonitor -MethodName WmiSetBrightness -Arguments $Args
            } catch {
                $PSCmdlet.ThrowTerminatingError(
                    (New-TerminatingErrorRecord "Brightness control is unsupported." DeviceError "BrightnessControlUnsupported" -Exception $_.Exception))
            }

        Reports a friendly message while preserving the caught WMI exception as the
        InnerException for diagnostics.

        .NOTES
        Internal helper; not exported from the module. It returns a record instead of throwing
        because ThrowTerminatingError must be invoked on the caller's $PSCmdlet for correct
        attribution.
    #>
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory)]
        [string] $Message,

        [Parameter(Mandatory)]
        [ErrorCategory] $Category,

        [string] $ErrorId,

        [object] $TargetObject,

        [Exception] $Exception
    )

    if ([string]::IsNullOrEmpty($ErrorId)) {
        $ErrorId = $Category
    }

    $ErrorException = $Exception ? [Exception]::new($Message, $Exception) : [Exception]::new($Message)

    [ErrorRecord]::new($ErrorException, $ErrorId, $Category, $TargetObject)
}
