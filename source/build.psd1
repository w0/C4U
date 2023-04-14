@{
    ModuleManifest  = "C4U.psd1"
    # Subsequent relative paths are to the ModuleManifest
    OutputDirectory = "../"
    VersionedOutputDirectory = $true
    SourceDirectories = @(
        'public'
        'private'
        'classes'
        'enum'
    )
}