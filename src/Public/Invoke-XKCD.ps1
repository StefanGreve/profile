using namespace System.IO
using namespace System.Net.Http
using namespace System.Net.Http.Headers

function Invoke-XKCD {
    <#
        .SYNOPSIS
        Retrieves XKCD comics based on the specified parameters.

        .DESCRIPTION
        XKCD is a serial web comic created in 2005 by American author Randall Munroe.
        The comic's tagline describes it as "a web comic of romance, sarcasm, math,
        and language". Munroe states on the comic's website that the name of the
        comic is not an initialism but "just a word with no phonetic pronunciation".

        .PARAMETER All
        Retrieves all available XKCD comics.

        .PARAMETER Number
         Retrieves specific XKCD comic based on its identifier (ID).

        .PARAMETER Random
        Retrieves a random XKCD comic.

        .PARAMETER From
         Specifies the starting number of a range of XKCD comics to retrieve.
         Must be used with the -To parameter.

        .PARAMETER To
        Specifies the ending number of a range of XKCD comics to retrieve.
        Must be greater than the value of -From.

        .PARAMETER Last
        Retrieves the last N comics, where N is specified by this parameter.

        .PARAMETER Path
        Specifies the directory where downloaded XKCD comics will be saved.
        The default path is the current working directory.

        .PARAMETER Download
         Indicates that the retrieved XKCD comics should be downloaded to the
         specified -Path.

        .PARAMETER Force
        Forces overwriting of existing files during download operations, if they
        already exist in the specified path.

        .INPUTS
        None. You can't pipe objects to Invoke-XKCD.

        .EXAMPLE
        PS> Invoke-XKCD -Number 42

        Retrieves information about the XKCD comic #42.

        .EXAMPLE
        PS> Invoke-XKCD -Random

        Retrieves a random XKCD comic.

        .EXAMPLE
        PS> Invoke-XKCD -From 10 -To 20

        Retrieves XKCD comics numbered 10 through 20.

        .EXAMPLE
        PS> Invoke-XKCD -Last 1 -Download -Path "C:\Comics"

        Downloads the latest XKCD comic to the "C:\Comics" directory.

        .EXAMPLE
        PS> Invoke-XKCD -All -Download

        Downloads all XKCD comics to the current working directory.

        .OUTPUTS
        XKCD. The function returns a XKCD object with properties describing the comic.

        .LINK
        https://xkcd.com/
        https://en.wikipedia.org/wiki/Xkcd
    #>
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
                    "https://xkcd.com/$Id/"
                ))
            } catch {
                Write-Error "A comic with ID=${Id} does not exist." -Category InvalidArgument -ErrorAction Stop
            }
        }
    }
    clean {

    }
}
