[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet('Default', 'Init', 'Setup', 'CombineFunctionsAndStage', 'ImportStagingModule', 'Analyze', 'Test', 'CreateBuildArtifact', 'Cleanup')]
    [System.String[]]
    $TaskList = 'Default',

    [Parameter()]
    [System.Collections.Hashtable]
    $Parameters,

    [Parameter()]
    [System.Collections.Hashtable]
    $Properties,

    [Parameter()]
    [Switch]
    $ResolveDependency
)

Write-Output -InputObject "`nSTARTED TASKS: $($TaskList -join ',')`n"

Write-Output -InputObject "`nPowerShell Version Information:"
$PSVersionTable

# Load dependencies
if ($PSBoundParameters.Keys -contains 'ResolveDependency') {
    # Install build dependencies from depend.psd1 via PSResourceGet.
    # TrustRepository: PSGallery registers as Trusted=False under PSResourceGet,
    # so the install would otherwise prompt and fail non-interactively.
    $psdependencyConfigPath = Join-Path -Path $PSScriptRoot -ChildPath 'depend.psd1'
    Write-Output -InputObject "Checking / resolving module dependencies from [$psdependencyConfigPath]..."
    $data = Import-PowerShellDataFile -Path $psdependencyConfigPath
    foreach ($name in ($data.Keys | Where-Object { $_ -ne 'PSDependOptions' })) {
        Install-PSResource -Name $name -Version $data[$name] -Repository 'PSGallery' -TrustRepository -Scope 'CurrentUser' -ErrorAction 'Stop'
    }

    # Remove ResolveDependency PSBoundParameter ready for passthru to PSake
    $PSBoundParameters.Remove('ResolveDependency')
}
else {
    Write-Output -InputObject "Skipping dependency check...`n"
}

# Set build environment variables
$env:BHProjectPath = $PSScriptRoot | Split-Path -Parent
$manifestFile = Get-ChildItem -Path $env:BHProjectPath -Filter '*.psd1'
$env:BHProjectName = $manifestFile.BaseName
$env:BHPSModuleManifest = $manifestFile.FullName

# Execute PSake tasts
$invokePsakeParams = @{
    buildFile = (Join-Path -Path $env:BHProjectPath -ChildPath 'Build\build.psake.ps1')
    nologo    = $true
}
Invoke-psake @invokePsakeParams @PSBoundParameters

Write-Output -InputObject "`nFINISHED TASKS: $($TaskList -join ',')"
exit ( [int](-not $psake.build_success) )
