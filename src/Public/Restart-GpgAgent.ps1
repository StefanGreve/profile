function Restart-GpgAgent {
    process {
        gpgconf --kill gpg-agent
        gpgconf --launch gpg-agent
    }
}
