
function Update-Package {
    [CmdletBinding()]
    param (

        # Do not check if the latest version is already in configmgr
        [Parameter()]
        [switch]
        $NoCheckConfigMgr,

        # Do not update the local Configuration file.
        [Parameter()]
        [switch]
        $SkipConfigFile,

        #Do not show any Write-Host output.
        [switch] 
        $NoHostOutput
    )

    function Update-Files {
        'Updating Files' | Log
        '  $Latest data:' | Log

        ($global:Latest.keys | Sort-Object | ForEach-Object { $v=$global:Latest[$_]; "    {0,-25} {1,-12} {2}" -f $_, "($( if ($v) { $v.GetType().Name } ))", $v }) | Log
        
        if (-not $SkipConfigFile) {
            "  $($Application.ConfigFile.Name)" | Log

            ('    updating version: {0} -> {1}' -f $Application.ConfigVersion, $Application.RemoteVersion) | Log

            $Application.UpdateVersion($Latest.Version)

            $Application.SaveConfiguration()
        }

        $sr = cu_SearchReplace

        $sr | ForEach-Object {
            $FileName = $_
            "  $FileName" | Log
            $FileContent = Get-Content $FileName -Encoding utf8 

            $Latest.GetEnumerator() | ForEach-Object {
                $VarRegex = "{{$($_.Key)}}"
                # Display matched {{VAR}}
                if ($FileContent -match $Regex) { 
                    ('    {{{{{0}}}}} = {1}' -f $_.Name, $_.Value) | Log
                    $FileContent = $FileContent -replace $VarRegex, $_.Value
                }
            }

            $UseBomEncoding = if ($FileName.EndsWith('.ps1')) { $true } else { $false }
            $Encoding = New-Object System.Text.UTF8Encoding($UseBomEncoding)
            $Output = $FileContent | Out-String
            [System.IO.File]::WriteAllText((Get-Item $FileName).FullName, $Output, $Encoding)
            
        }
    }

    function Start-Update {
        $Application.Updated = $false

        $Global:Latest = $Script:cu_Latest
        
        $Application.RemoteVersion = $Latest.Version

        "config version: $($Application.ConfigVersion)" | Log
        "remote version: $($Application.RemoteVersion)" | Log

        if ([version] $Application.RemoteVersion -gt [version] $Application.ConfigVersion) {
            if (-not $NoCheckConfigMgr) { 
                $AppFilter = 'DisplayName eq ''{0} {1} {2}''' -f $Application.Publisher, $Application.PackageName, $Latest.Version
                $ExistingApp = Confirm-ExistingVersion -ServerFQDN $cu_ServerFQDN -Source Application -Filter $AppFilter
            }
        } else {
            'No new version found' | Log
            return
        }

        if ($null -ne $ExistingApp) {
            "New version available but already in created in Configmgr"
            return
        }

        'New version is available!' | Log

        $SourceDirectory = ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "cmbuilder", "cu", $Latest.Name))
        New-Item $SourceDirectory -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

        $Latest.Add('SourceDirectory', $SourceDirectory)

        switch ($Latest.Keys) {
            'URL'		{ $Global:Latest += Get-RemoteFiles -Url $Latest.URL -Destination $SourceDirectory }
            'FILE'		{ Get-LocalContent -File $Latest.File -Destination $SourceDirectory }
            'DIRECTORY' { Get-LocalContent -File $Latest.Directory -Destination $SourceDirectory }
        }

        if ($Latest.FileName -match ".msi$") {
            $MSIInfo = Get-MsiFileInfo $Latest.FilePath
            $Latest.Add("ProductCode", $MSIInfo.ProductCode)
            $Latest.Add("ProductVersion", $MSIInfo.ProductVersion)
        }

        try {
            Update-Files
        } catch {
            $_
        }

        try {

            $StartBuilder = @{
                ConfigFile              = $Application.ConfigFile
                SourceDirectory         = $SourceDirectory
                SiteServerFQDN          = $cu_ServerFQDN
                SiteCode                = $cu_SiteCode
                ContentShare            = $cu_ContentShare
                DistributionPoints      = $cu_DistributionPoints
                DistributionPointGroups = $cu_DistributionPointGroups
                ApplicationFolder       = $cu_ApplicationFolder
                CollectionFolder        = $cu_CollectionFolder
                TaskSequenceSkipList    = $cu_TaskSequenceSkipList
                CopyDeployment          = $cu_CopyDeployment
            }
            
            Write-Verbose "CMBuilder Options: $($StartBuilder | Out-String)"

            Start-Builder | Write-Verbose
        } catch {
            
        }

        $Application.Updated = $true

        # Revert configuration to maintain {{VAR}} replace functionality 
        $Application.SaveConfiguration()

    }

    function Log() {
        $input | ForEach-Object {
            $Application.Log += $_
            if (-not $NoHostOutput) { Write-Host $_ }
        }
    }


    # Determine where the script execution started.
    if ($PSCmdlet.MyInvocation.ScriptName -eq '') {
        Write-Verbose 'Running outside of an update script.'
        if (-not (Test-Path update.ps1)) { return 'update.ps1 not found in the Current Directory.' }
    } else {
        Write-Verbose 'Running inside of an update script.'
    }

    $Application = [CUPackage]::New($PWD)

    try {
        $Result = cu_GetLatest | Select-Object -Last 1

        if ($null -eq $Result) { throw 'cu_GetLatest returned nothing.'}

        if ($Result -eq 'ignore') { return $Result }

        $ResultType = $Result.GetType()
        if ($ResultType -ne [hashtable]) { throw "cu_GetLatest doesn't return a hashtable. Returned type is $ResultType"}

    } catch {
        throw "cu_GetLatest Failed`n$_"
    }

    $Script:cu_Latest = $Result

    Start-Update

    if ($Application.Updated) {
        '' | Log
        'Application Updated' | Log
    }
    return $Application
}

Set-Alias update Update-Package