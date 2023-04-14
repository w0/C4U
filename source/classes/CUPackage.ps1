
class CUPackage {
    [string]      $Path
    [string]      $Name
    [string]      $Publisher
    [string]      $PackageName
    [bool]        $Updated
    [string]      $RemoteVersion
    [string]      $ConfigVersion
    [string[]]    $Log
    [string]      $Error
    [io.fileinfo] $ConfigFile
    [object]      $Configuration
    [bool]        $Ignored
    [string]      $IgnoreMessage

    CUPackage([string] $Path) {
        if ( [String]::IsNullOrWhiteSpace($Path)) { throw 'Configuration path cannot be null or empty.' }

        $this.Path = $Path
        $this.Name = $Path | Split-Path -Leaf

        $this.ConfigFile = Get-ChildItem -Path $this.Path | Where-Object { 
            $_.Extension -eq '.yaml' -or $_.Extension -eq '.xml' }

        switch ($this.ConfigFile.Extension) {
            '.xml' { 
                $this.Configuration = [CUPackage]::ReadXML($this.ConfigFile.FullName)
                $this.ConfigVersion = $this.Configuration.package.SoftwareVersion
                $this.Publisher     = $this.Configuration.package.Publisher
                $this.PackageName   = $this.Configuration.package.Name
                break
            }
            '.yaml' {
                $this.Configuration = [CUPackage]::ReadYAML($this.ConfigFile.FullName)
                $this.ConfigVersion = $this.Configuration.SoftwareVersion
                $this.Publisher     = $this.Configuration.Publisher
                $this.PackageName   = $this.Name
                break
            }
            Default { throw 'Unable to locate a supported package configuration' }
        }

    }

    static [xml] ReadXML ($ConfigPath) {
        $XML = New-Object xml
        $XML.PreserveWhitespace = $true
        $XML.Load($ConfigPath)

        return $XML
    }

    static [System.Collections.Specialized.OrderedDictionary] ReadYAML ($ConfigPath) {
        $YAML = Get-Content $ConfigPath | ConvertFrom-Yaml -Ordered
        return $YAML
    }

    UpdateVersion($Version) {
        switch ($this.ConfigFile.Extension) {
            '.xml'  { $this.Configuration.package.SoftwareVersion = $Version }
            '.yaml' { $this.Configuration.SoftwareVersion = $Version         }
        }
    }

    SaveConfiguration() {
        $FileContent = ""

        switch ($this.ConfigFile.Extension) {
            '.xml' {
                $FileContent = $this.Configuration.InnerXml 
                break 
            }
            '.yaml' { 
                $FileContent = $this.Configuration | ConvertTo-Yaml
                break
            }
            Default { throw 'Unable to determine filetype.' }
        }

        $UseBomEncoding = New-Object System.Text.UTF8Encoding($False)
        [System.IO.File]::WriteAllText($this.ConfigFile.FullName, $FileContent, $UseBomEncoding)
    }

    
    [hashtable] Serialize() {
        $res = @{}
        $this | Get-Member -Type Properties | Where-Object {$_.Name -ne 'Configuration' } | ForEach-Object {
            $property = $_.Name
            $res.Add($property, $this.$property)
        }

        return $res
    }
}
