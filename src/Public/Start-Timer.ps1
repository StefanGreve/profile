using namespace System
using namespace System.Diagnostics

function Start-Timer {
    <#
        .SYNOPSIS
        Starts a countdown timer and provides real-time progress updates.

        .DESCRIPTION
        The Start-Timer function starts a countdown timer for a specified duration.
        The duration can be provided in seconds, minutes, or hours, depending on the
        parameter set used. The function displays a progress bar indicating the
        percentage completed and the estimated time remaining.

        .PARAMETER Seconds
        Specifies the duration of the timer in seconds.

        .PARAMETER Minutes
        Specifies the duration of the timer in minutes.

        .PARAMETER Hours
        Specifies the duration of the timer in hours.

        .INPUTS
        None. You can't pipe objects to Start-Timer.

        .EXAMPLE
        PS> Start-Timer -Seconds 30

        Starts a 30-second countdown timer and displays the progress bar.

        .EXAMPLE
        PS> Start-Timer -Hours 1

        Starts a 1-hour countdown timer and displays the progress bar.

        .OUTPUTS
        None. This function does not produce any output.
    #>
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
