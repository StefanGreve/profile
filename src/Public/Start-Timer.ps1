using namespace System
using namespace System.Diagnostics

function Start-Timer {
    [OutputType([void])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = "Seconds")]
        [int] $Seconds,

        [Parameter(Mandatory, ParameterSetName = "Minutes")]
        [int] $Minutes,

        [Parameter(Mandatory, ParameterSetName = "Hours")]
        [int] $Hours
    )

    begin {
        $CountDown = switch ($PSCmdlet.ParameterSetName) {
            "Seconds" {
                $Seconds
            }
            "Minutes" {
                $Minutes * 60
            }
            "Hours" {
                $Hours * 3600
            }
        }

        $StartDate = [DateTime]::Now
        $StopWatch = [Stopwatch]::StartNew()
        [int] $t = 0
    }
    process {
        while ($t -le $CountDown) {
            [int] $PercentComplete = [Math]::Round($t * 100 / $CountDown, 0)
            Write-Progress -Activity "Timer" -Status "$PercentComplete%" -PercentComplete $PercentComplete -SecondsRemaining ($CountDown - $t)
            $t = $StopWatch.Elapsed.TotalSeconds
        }
    }
    end {
        Write-Verbose "Timer finished after $CountDown seconds (start date: $StartDate)"
    }
}
