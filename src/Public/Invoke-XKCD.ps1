using namespace System.IO
using namespace System.Net.Http
using namespace System.Net.Http.Headers

function Invoke-XKCD {
    [Alias("xkcd")]
    [OutputType([XKCD])]
    [CmdletBinding(DefaultParameterSetName = "Last", SupportsShouldProcess, ConfirmImpact = "Low")]
    param(
        [Parameter(Mandatory, ParameterSetName = "All")]
        [switch] $All,

        [Parameter(Mandatory, ParameterSetName = "Number")]
        [int[]] $Number,

        [Parameter(Mandatory, ParameterSetName = "Random")]
        [switch] $Random,

        [Parameter(Mandatory, ParameterSetName = "Range")]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $From,

        [Parameter(Mandatory, ParameterSetName = "Range")]
        [ValidateScript({
            if ($_ -le $From) {
                Write-Error "The value of -To must be greater than -From" -Category InvalidArgument -ErrorAction Stop
            }

            return $true
        })]
        [int] $To,

        [Parameter(ParameterSetName = "Last")]
        [int] $Last = 1,

        [string] $Path = $PWD.Path,

        [switch] $Download,

        [switch] $Force
    )

    begin {
        # The Info response contains the following data:
        #
        # ======================================================================
        # KEY         TYPE    NULLABLE    REMARKS
        # ======================================================================
        # year        int                 year of publication
        # month       int                 month of publication
        # day         int                 day of publication
        # num         int                 running number of comic
        # title       string              title of website
        # safe_title  string              ASCII-friendly title
        # alt         string              alt text on image
        # link        string      X       ?
        # img         string              DDL to comic
        # news        string      X       ?
        # transcript  string      X       ?
        # ======================================================================
        $Info = if (!$MyInvocation.BoundParameters.ContainsKey("Number") -or $null -eq $Number) {
            Invoke-RestMethod -Uri "https://xkcd.com/info.0.json"
        }

        [int[]] $Ids = switch ($PSCmdlet.ParameterSetName) {
            "All" {
                @(1..$Info.Num)
            }
            "Number" {
                $Number
            }
            "Random" {
                @([System.Random]::Shared.Next(1, $Info.Num))
            }
            "Range" {
                @($From..$To)
            }
            "Last" {
                @(($Info.Num - $Last + 1)..$Info.Num)
            }
            default {
                1
            }
        }
    }
    process {
        for ([int] $i = 0; $i -lt $Ids.Count; $i++) {
            $Id = $Ids[$i]

            try {
                $Response = Invoke-RestMethod -Uri "https://xkcd.com/$Id/info.0.json"
                $FileExtension = $Response.Img.Split("/")[-1].Split(".")[1]
                $FilePath = [Path]::Combine($Path, "${Id}.${FileExtension}")
                Write-Host "test $id"

                if ($Download.IsPresent -and $PSCmdlet.ShouldProcess($Response.img, "Download $($FilePath)")) {
                    [int] $PercentComplete = [Math]::Round($i / $Ids.Count * 100, 0)

                    Write-Progress -Activity "Download XKCD ${Id}" `
                        -Status "${PercentComplete}%" `
                        -PercentComplete $PercentComplete

                    Write-Verbose "Downloading $Id to $Path"
                    Invoke-WebRequest -Uri $Response.img -OutFile $FilePath
                }

                Write-Output $([XKCD]::new(
                    $Id,
                    $Response.title,
                    $Response.alt,
                    $Response.year,
                    $Response.month,
                    $Response.day,
                    $Response.link
                ))
            } catch {
                Write-Error "A comic with ID = $ID does not exist." -Category InvalidArgument -ErrorAction Stop
            }
        }
    }
    clean {

    }
}
