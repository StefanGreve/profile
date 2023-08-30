$Desktop = [Environment]::GetFolderPath("Desktop")
$ParentFolder = Join-Path -Path $Desktop -ChildPath "repos"
$Repository = New-Item -Path $ParentFolder -ItemType Directory -Force

Push-Location $Repository.FullName

if (!(Test-Path $Repository)) {
    git clone "git@github.com:StefanGreve/profile.git"
}

# current user, all hosts
$ProfilePath = [OperatingSystem]::IsLinux() -or [System.OperatingSystem]::IsMacOS() ? "~/.config/powershell/profile.ps1" : "$HOME\Documents\PowerShell\Profile.ps1"

$Value = Join-Path -Path $Repository.FullName -ChildPath "profile.ps1"

$ProfileFile = New-Item -Path $ProfilePath -ItemType SymbolicLink -Value $Value -Force

Write-Host "Linked PowerShell profile:`n$Value -> $($ProfileFile.Target)" -ForegroundColor Green

Pop-Location
