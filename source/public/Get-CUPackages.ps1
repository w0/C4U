
function Get-CUPackages {
    [CmdletBinding()]
    param (
        # Return specific package by name.
        [Parameter()]
        [ValidateScript({ 
            (-not [string]::IsNullOrEmpty($_))
            },
            ErrorMessage = "Name is either null or an empty string."
        )]
        [string]
        $Name
    )
    
    process {
        $root = $global:cu_Root

        if (-not $root) { $root = $pwd }

        Get-ChildItem ([System.IO.Path]::Combine($root, '*', 'update.ps1')) | ForEach-Object {
            $PackageDir = Get-Item (Split-Path $PSItem)

            if ($Name -and ($PackageDir.Name -ne $Name)) { return }

            if ($PackageDir.Name -like '_*') { return }
            
            $PackageDir

        }
    }    
}

Set-Alias gcu Get-CUPackages
Set-Alias lscu Get-CUPackages