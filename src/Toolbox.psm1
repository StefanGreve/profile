using namespace System.Management.Automation

#region Export Classes

$ExportableTypes = @(
    [Battery]
)

$TypeAcceleratorsClass = [psobject].Assembly.GetType('System.Management.Automation.TypeAccelerators')

# Ensure none of the types would clobber an existing type accelerator.
# If a type accelerator with the same name exists, throw an exception.
$ExistingTypeAccelerators = $TypeAcceleratorsClass::Get
foreach ($Type in $ExportableTypes) {
    if ($Type.FullName -in $ExistingTypeAccelerators.Keys) {
        $Message = @(
            "Unable to register type accelerator `"$($Type.FullName)`""
            "Accelerator already exists."
        ) -join " - "

        throw [ErrorRecord]::new(
            [System.InvalidOperationException]::new($Message),
            "TypeAcceleratorAlreadyExists",
            [ErrorCategory]::InvalidOperation,
            $Type.FullName
        )
    }
}

# Add type accelerators for every exportable type.
foreach ($Type in $ExportableTypes) {
    $TypeAcceleratorsClass::Add($Type.FullName, $Type)
}

# Remove type accelerators when the module is removed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    foreach ($Type in $ExportableTypes) {
        $TypeAcceleratorsClass::Remove($Type.FullName)
    }
}.GetNewClosure()

#endregion

#region Export Functions

$Public = @(Get-ChildItem -Path "${PSScriptRoot}\Public\*.ps1" -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path "${PSScriptRoot}\Private\*.ps1" -ErrorAction SilentlyContinue)

foreach ($Import in @($Public + $Private)) {
    try {
        . $Import.FullName
    }
    catch {
        Write-Error -Message "Failed to import function $($Import.FullName): $_"
    }
}

Export-ModuleMember -Function $Public.BaseName -Cmdlet * -Alias *

#endregion
