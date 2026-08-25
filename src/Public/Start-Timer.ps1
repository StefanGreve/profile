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

        .OUTPUTS
        None. This function does not produce any output.

        .EXAMPLE
        PS> Start-Timer -Seconds 30

        Starts a 30-second countdown timer and displays the progress bar.

        .EXAMPLE
        PS> Start-Timer -Hours 1

        Starts a 1-hour countdown timer and displays the progress bar.
    #>
    [OutputType([void])]
    [CmdletBinding()]
    param(
        [ValidateRange(1, [int]::MaxValue)]
        [Parameter(Mandatory, ParameterSetName = "Seconds")]
        [int] $Seconds,

        [ValidateRange(1, [int]::MaxValue)]
        [Parameter(Mandatory, ParameterSetName = "Minutes")]
        [int] $Minutes,

        [ValidateRange(1, [int]::MaxValue)]
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
    }
    process {
        while ($StopWatch.Elapsed.TotalSeconds -lt $CountDown) {
            $Elapsed = $StopWatch.Elapsed.TotalSeconds
            [int] $PercentComplete = [Math]::Round($Elapsed * 100 / $CountDown, 0)

            $ProgressArgs = @{
                Activity = "Timer"
                Status = "$PercentComplete%"
                PercentComplete = $PercentComplete
                SecondsRemaining = [Math]::Ceiling($CountDown - $Elapsed)
            }

            Write-Progress @ProgressArgs

            # Yield the CPU between updates so the countdown
            # loop doesn't spin at ~100% on one core.
            Start-Sleep -Milliseconds 250
        }
    }
    end {
        Write-Verbose "Timer finished after $CountDown seconds (start date: $StartDate)"
    }
}
