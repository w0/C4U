
function Get-RemoteFiles {
    [CmdletBinding()]
    param (
        # Url to download 
        [Parameter(Mandatory = $true, ValueFromPipeline)]
        [string]
        $Url,
        
        # Destination 
        [Parameter(Mandatory = $true)]
        [io.directoryInfo]
        $Destination,

        [Parameter()]
        [string]
        $FileNameBase

    )

    function Get-FileName ($Url){
        $FileName = ([uri] $Url).Segments[-1]
        $FileName -replace '%20', '_'
    }

    $FileName = Get-FileName $Url

    $FilePath = Join-Path $Destination $FileName

    try {    
        Write-Host "Downloading > $FileName <"
        
        Invoke-WebRequest -Uri $Latest.URL -OutFile $FilePath
    
    } catch { throw $_ }
    
    Write-Output @{ 
        FileName = $FileName
        FilePath = $FilePath
    }

}