function Restart-GpgAgent {
    <#
        .SYNOPSIS
        Restarts the GPG agent.

        .DESCRIPTION
        The Restart-GpgAgent function stops the running GPG agent process and relaunches it.

        .INPUTS
        None. You can't pipe objects to Restart-GpgAgent.

        .EXAMPLE
        PS> Restart-GpgAgent

        Restarts the GPG agent.

        .OUTPUTS
        None. This function does not produce any output.
    #>
    [OutputType([void])]
    param()

    process {
        gpgconf --kill gpg-agent
        gpgconf --launch gpg-agent
    }
}
