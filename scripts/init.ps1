begin {
    $ProjectRoot = Split-Path -Path $PSScriptRoot -Parent
    Push-Location $ProjectRoot
}
process {
    dotnet tool restore
    dotnet husky install
}
clean {
    Pop-Location
}
