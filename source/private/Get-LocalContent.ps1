function Get-LocalContent {
    [CmdletBinding()]
    param (
        [Parameter()]
        [io.FileInfo]
        $File,

        [Parameter()]
        [io.DirectoryInfo]
        $Directory,

        [Parameter()]
        $Destination
    )
    

    switch ($PSBoundParameters.Keys) {
        'File' {
            $ContentCopy = @{
                Path = $File
                Destination = $Destination
            }
        }
        'Directory' {
            $ContentCopy = @{
                Path = $Directory
                Destination = $Destination
            }
        }
    }


    Copy-Item @ContentCopy

}