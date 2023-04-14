
if (-not (Get-Module InvokeBuild -ListAvailable)) {
    Install-Module InvokeBuild -Scope CurrentUser
}

Invoke-Build

Import-Module .\Output\C4U -Force -Verbose
