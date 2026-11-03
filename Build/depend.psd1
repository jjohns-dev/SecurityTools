@{
    # Defaults for all dependencies
    PSDependOptions  = @{
        Target     = 'CurrentUser'
        Parameters = @{
            # Use a local repository for offline support
            Repository         = 'PSGallery'
            SkipPublisherCheck = $true
        }

    }

    # Dependency Management modules
    # PackageManagement = '1.2.2'
    # PowerShellGet     = '2.0.1'

    # Common modules
    Pester           = '6.2.0'
    psake            = '5.0.4'
    #PSDeploy         = '1.0.5'
    PSScriptAnalyzer = '1.24.0'
    ImportExcel      = '7.8.10'
}
