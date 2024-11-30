using namespace System
using namespace System.Management.Automation

#region Export Functions and Classes

$Classes = @(Get-ChildItem -Path "${PSScriptRoot}\Classes\*.ps1" -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path "${PSScriptRoot}\Private\*.ps1" -ErrorAction SilentlyContinue)
$Public = @(Get-ChildItem -Path "${PSScriptRoot}\Public\*.ps1" -ErrorAction SilentlyContinue)

foreach ($Import in @($Classes + $Private + $Public)) {
    try {
        $File = $Import.FullName
        . $File
        Write-Host "[ OK ] " -ForegroundColor Green -NoNewline
        Write-Host "Importing ${File}"
    }
    catch {
        Write-Host "[ ER ] " -ForegroundColor Red -NoNewline
        Write-Host "Failed to import file ${File}: $_"
    }
}

Export-ModuleMember -Function $Public.BaseName -Cmdlet * -Alias *

#endregion

#region Exporting Classes with Type Accelerators

$ExportableTypes =@(
    [Battery]
)

$TypeAcceleratorsClass = [PSObject].Assembly.GetType(
    "System.Management.Automation.TypeAccelerators"
)

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
            [InvalidOperationException]::new($Message),
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
