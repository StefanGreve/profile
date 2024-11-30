using namespace System

function Export-Branch {
    [OutputType([void])]
    [Alias("git-fire")]
    [SuppressMessage("PSAvoidUsingCmdletAliases", "")]
    param(
        [string] $Message,

        [int] $ShutdownDelay = 15
    )

    begin {
        $Author = git config user.name
        $Remotes = git remote
        $CurrentBranch = git branch --show-current
        $NewBranch = "fire/$CurrentBranch/${env:COMPUTERNAME}/${env:USERNAME}"

        $IsValidBranch = $(git check-ref-format --branch $NewBranch 2>&1) -eq $NewBranch

        git fetch --all --quiet
        $RemoteBranches = git branch --remote --format="%(refname:lstrip=3)"

        if (!$IsValidBranch -or $RemoteBranches.Contains($NewBranch)) {
            $Salt = Get-Salt -MaxLength 16
            $RandomString = [BitConverter]::ToString($Salt).Replace("-", [string]::Empty)
            $NewBranch = "fire/$CurrentBranch/$RandomString"
         }

        Push-Location $(git rev-parse --show-toplevel)
    }
    process {
        Write-Host "$Author, leave the building now!".ToUpper()  -ForegroundColor Red
        Write-Host "We will take it from here.`n"

        Write-Host "[1/4] Creating a new branch and moving all files to the staging area" -ForegroundColor Yellow
        git checkout -b $NewBranch
        git add --all

        Write-Host "[2/4] Committing WIP" -ForegroundColor Yellow
        $DefaultMessage = "🔥 Fire! If you are in the same building as $Author, evacuate immediately!"
        $Message = $PSBoundParameters.ContainsKey("Message") ?  $Message : $DefaultMessage
        git commit -m $Message --no-verify --no-gpg-sign

        Write-Host "[3/4] Push last commit to all remotes" -ForegroundColor Yellow
        $Remotes | ForEach-Object { git push --set-upstream $_ $NewBranch --no-verify }

        Write-Host "[4/4] Push all notes to all remotes" -ForegroundColor Yellow
        $Remotes | ForEach-Object { git push $_ refs/notes/* --no-verify }
    }
    clean {
        Pop-Location

        $ExitMessage = "Turn around and evacuate the building immediately".ToUpper()
        $InfoMessage = "This computer will shutdown automatically in $ShutdownDelay seconds . . ."

        if ($IsWindows) {
            shutdown.exe /s /f /t $ShutdownDelay /d P:4:1 /c $([string]::Format("{0}`n`n{1}", $ExitMessage, $InfoMessage))
        } elseif ($IsLinux) {
            Write-Host $ExitMessage -ForegroundColor Red
            Write-Host $InfoMessage
            sleep $ShutdownDelay
            systemctl poweroff
        } elseif ($IsMacOS) {
            Write-Host $ExitMessage -ForegroundColor Red
            osascript -e $InfoMessage
            sudo shutdown -h now
        } else {
            Write-Error $OperatingSystemNotSupportedError -Category NotImplemented -ErrorAction Stop
        }
    }
}
