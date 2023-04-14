
function Update-CUPackages {
    [CmdletBinding()]
    param (
        # Array of package names to run.
        [Parameter()]
        [string[]]
        $Name,

        # Hashtable of options
        [Parameter()]
        [System.Collections.Specialized.OrderedDictionary]
        $Options = @{}
    )

    if (-not $Options.Jobs)    { $Options.Jobs = 10}
    if (-not $Options.Timeout) { $Options.Timeout = 900 }  # Timeout of 15 minutes

    $StartTime = Get-Date

    Remove-Job * -Force

    $TempDir = ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "cmpackager", "cu"))
    
    New-Item -Path $TempDir -ItemType Directory -ErrorAction 0 | Out-Null

    Get-ChildItem $TempDir | Remove-Item -Recurse -Force

    $CUPackages = Get-CUPackages

    $Result = @() 
    $j = $p = 0 

    while ($p -ne $CUPackages.length) {
        
        foreach ($Job in (Get-Job | Where-Object State -ne 'Running')) {
            $p += 1

            if ('Stopped', 'Failed', 'Completed' -notcontains $Job.State) {
                Write-Host "Invalid job state for $($Job.Name): $($Job.State)"
            } else {
                Write-Verbose "$($Job.Name): $($Job.State)"

                if ($Job.ChildJobs[0].JobStateInfo.Reason.Message) {
                    $Application = [CUPackage]::New((Get-CUPackages $Job.Name))
                    $Application.Error = $Job.ChildJobs[0].JobStateInfo.Reason.Message

                } else {
                    $Application = $null
                    Receive-Job $Job | Set-Variable Application

                    # Ignore was return from an update.ps1
                    $ignored = $Application -eq 'ignore'

                    if ( -not $Application -or $ignored) {
                        $Application = [CUPackage]::New((Get-CUPackages $Job.Name)) 
                        
                        if ($ignored) {
                            
                            $Application.Ignored = $true

                        } elseif ($Job.State -eq 'Stopped') {
                            $Application.Error = "Job was terminated. $($Options.Timeout) UpdateTimeout was exceeded."
                        } else {
                            $Application.Error = 'Job returned no object.'
                        }
                    }
                }
            
                
                Remove-Job $Job

                $JobRunTime = ($Job.PSEndTime.TimeOfDay - $Job.PSBeginTime.TimeOfDay).TotalSeconds
                $JobMessage = '[{0}/{1}] {2} ' -f $p, $CUPackages.Length, $Application.Name
                $JobMessage += if ($Application.Updated) { 'is updated to {0}' - $Application.RemoteVersion } else { 'has no updates' }
                
                if ($Application.Error) {
                    $JobMessage = '[{0}/{1}] {2} ERROR: ' -f $p, $CUPackages.Length, $Application.Name
                    $JobMessage += $Application.Error.ToString() -split "`n" | ForEach-Object { "`n" + ' '*5 + $_ }
                }

                $JobMessage += ' ({0:N2}s)' -f $JobRunTime
                Write-Host '  ' $JobMessage

                $Result += $Application

            }
        }

        # Get count of jobs in any run state.
        $JobCount = (Get-Job | Measure-Object).count

        if (($JobCount -eq $Options.Jobs) -or ($j -eq $CUPackages.Length)) {
            Start-Sleep 1
            foreach ($Job in $(Get-Job -State Running)) {
                $RunTime = (New-TimeSpan $job.PSBeginTime (Get-Date)).TotalSeconds
                
                if ($RunTime -ge $Options.Timeout) { Stop-Job $Job}
            }
            continue
        }


        $AppPath = $CUPackages[$j++]
        $AppName = Split-Path $AppPath -Leaf
        
        Write-Verbose "Starting: $AppName"

        Start-Job -Name $AppName {
            
            
            $Name = $using:AppName

            # Set the working directory for the Job.
            Set-Location $using:AppPath
            
            $Application = & ./update.ps1 6> $null

            if (-not $Application) { throw '{0} update script returned nothing' -f $Name }  
            
            $Application = $Application[-1]
            $ReturnType = $Application.GetType().Name
            
            if ($ReturnType -ne 'CUPackage') { throw '{0} update script did not return CUPackage but: {1}' -f $Name, $ReturnType }

            $Application

        } | Out-Null
    }

    $Result = $Result | Sort-Object name

    $Result
}

Set-Alias updateall Update-CUPackages