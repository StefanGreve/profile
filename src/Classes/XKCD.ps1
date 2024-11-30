using namespace System

class XKCD {
    [int] $Id
    [string] $Title
    [string] $AltText
    [DateTime] $ReleaseDate
    [string] $Link

    XKCD([int] $Id, [string] $Title, [string] $AltText, [int] $Year, [int] $Month, [int] $Day, [string] $Link) {
        $this.Id = $Id
        $this.Title = $Title
        $this.AltText = $AltText
        $this.ReleaseDate = [DateTime]::new($Year, $Month, $Day)
        $this.Link = $Link
    }
}
