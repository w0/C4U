
function Confirm-ExistingVersion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $ServerFQDN,

        [Parameter(Mandatory)]
        [string]
        $Source,

        [Parameter(Mandatory)]
        [string]
        $Filter
    )

    $Query = 'https://{0}/AdminService/v1.0/{1}?$filter={2}' -f $ServerFQDN, $Source, $Filter

    Write-Verbose "ExistingVersion Query: $Query"

    $AdminService = @{
        Uri = $Query
        UseDefaultCredentials = $true
    }

    Invoke-RestMethod @AdminService | Select-Object -ExpandProperty value

}

Set-Alias cev Confirm-ExistingVersion