function Restart-GpgAgent {
    <#
        .SYNOPSIS
        Restarts the GPG agent.

        .DESCRIPTION
        The Restart-GpgAgent function stops the running GPG agent process and relaunches it.

        .INPUTS
        None. You can't pipe objects to Restart-GpgAgent.

        .OUTPUTS
        None. This function does not produce any output.

        .EXAMPLE
        PS> Restart-GpgAgent

        Restarts the GPG agent.
    #>
    [OutputType([void])]
    [CmdletBinding()]
    param()

    process {
        gpgconf --kill gpg-agent
        gpgconf --kill keyboxd

        gpgconf --launch keyboxd
        gpgconf --launch gpg-agent
    }
}
