[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'psake exposes variables assigned in the Properties block to every Task scriptblock; PSScriptAnalyzer cannot follow that scope.'
)]
Param()

# PSake makes variables declared here available in other scriptblocks
Properties {
    $ProjectRoot = $env:BHProjectPath
    if (-not $ProjectRoot) {
        $ProjectRoot = $PSScriptRoot
    }

    $Timestamp = Get-Date -UFormat '%Y%m%d-%H%M%S'
    $PSVersion = $PSVersionTable.PSVersion.Major
    $lines = '----------------------------------------------------------------------'

    # Pester
    # SELECTS WHICH UNIT TESTS THE 'Test' TASK DISCOVERS:
    #   All           - cross-platform .tests.ps1 + Windows-only .tests.windows.ps1 (default; matches local-dev behavior)
    #   CrossPlatform - cross-platform .tests.ps1 only
    #   WindowsOnly   - .tests.windows.ps1 only
    # Override from the command line:  ./Build/build.ps1 -Properties @{ PesterScope = 'WindowsOnly' } -TaskList Test
    $PesterScope = 'All'
    $TestFile = "Test-Unit_$($TimeStamp).xml"

    # Script Analyzer
    [ValidateSet('Error', 'Warning', 'Any', 'None')]
    $ScriptAnalysisFailBuildOnSeverityLevel = 'Error'
    $ScriptAnalyzerSettingsPath = "$ProjectRoot/Build/PSScriptAnalyzerSettings.psd1"

    # Build
    $ArtifactFolder = Join-Path -Path $ProjectRoot -ChildPath 'Artifacts'

    # Staging
    $StagingFolder = Join-Path -Path $ProjectRoot -ChildPath 'Staging'
    $StagingModulePath = Join-Path -Path $StagingFolder -ChildPath $env:BHProjectName
    #$StagingModulePath = Join-Path -Path $StagingFolder -ChildPath $ProjectName
    $StagingModuleManifestPath = Join-Path -Path $StagingModulePath -ChildPath "$($env:BHProjectName).psd1"
    #$StagingModuleManifestPath = Join-Path -Path $StagingModulePath -ChildPath "$($ProjectName).psd1"
}

# Define top-level tasks
Task 'Default' -depends 'Test'

# Show build variables
Task 'Init' {
    $lines

    Set-Location $ProjectRoot
    'Build System Details:'
    Get-Item ENV:BH*
    "`n"
}

# Setup the Artifact and Staging folders
Task 'Setup' -depends 'Init' {
    $lines

    $foldersToSetup = @(
        $ArtifactFolder
        $StagingFolder
    )

    # Remove folders
    foreach ($folderPath in $foldersToSetup) {
        Remove-Item -Path $folderPath -Recurse -Force -ErrorAction 'SilentlyContinue'
        New-Item -Path $folderPath -ItemType 'Directory' -Force | Out-String | Write-Verbose
    }
}

# Create a single .psm1 module file containing all functions
# Copy new module and other supporting files (Examples) to Staging folder
Task 'CombineFunctionsAndStage' -depends 'Setup' {
    $lines

    # Create folders
    New-Item -Path $StagingFolder -ItemType 'Directory' -Force | Out-String | Write-Verbose
    New-Item -Path $StagingModulePath -ItemType 'Directory' -Force | Out-String | Write-Verbose

    # Get public and private function files
    #$publicFunctions = @( Get-ChildItem -Path "$env:BHModulePath\Public\*.ps1" -Recurse -ErrorAction 'SilentlyContinue' )
    #$privateFunctions = @( Get-ChildItem -Path "$env:BHModulePath\Private\*.ps1" -Recurse -ErrorAction 'SilentlyContinue' )

    # Combine functions into a single .psm1 module
    #$combinedModulePath = Join-Path -Path $StagingModulePath -ChildPath "$($env:BHProjectName).psm1"
    #@($publicFunctions + $privateFunctions) | Get-Content | Add-Content -Path $combinedModulePath

    # Copy other required folders and files
    $pathsToCopy = @(
        Join-Path -Path $ProjectRoot -ChildPath 'Private'
        Join-Path -Path $ProjectRoot -ChildPath 'Public'
        Join-Path -Path $ProjectRoot -ChildPath 'README.md'
        Join-Path -Path $ProjectRoot -ChildPath ($env:BHProjectName + '.psd1')
        Join-Path -Path $ProjectRoot -ChildPath ($env:BHProjectName + '.psm1')
    )
    Copy-Item -Path $pathsToCopy -Destination $StagingModulePath -Recurse

    # Copy existing manifest
    #Copy-Item -Path $env:BHPSModuleManifest -Destination $StagingModulePath -Recurse
}

# Import new module
Task 'ImportStagingModule' -depends 'Init', 'CombineFunctionsAndStage' {
    $lines
    Write-Output -InputObject "Reloading staged module from path: [$StagingModulePath]`n"

    # Reload module
    if (Get-Module -Name $env:BHProjectName) {
        Remove-Module -Name $env:BHProjectName -Force
    }
    Import-Module -Name $StagingModulePath -ErrorAction 'Stop' -Force
}

# Run PSScriptAnalyzer against code to ensure quality and best practices are used
Task 'Analyze' -depends 'ImportStagingModule' {
    $lines
    Write-Output -InputObject "Running PSScriptAnalyzer on path: [$StagingModulePath]`n"

    $Results = Invoke-ScriptAnalyzer -Path $StagingModulePath -Recurse -Settings $ScriptAnalyzerSettingsPath -Verbose:$VerbosePreference
    $Results | Select-Object 'RuleName', 'Severity', 'ScriptName', 'Line', 'Message' | Format-List

    switch ($ScriptAnalysisFailBuildOnSeverityLevel) {
        'None' {
            return
        }
        'Error' {
            Assert -conditionToCheck (
                ($Results | Where-Object 'Severity' -EQ 'Error').Count -eq 0
            ) -failureMessage 'One or more ScriptAnalyzer errors were found. Build cannot continue!'
        }
        'Warning' {
            Assert -conditionToCheck (
                ($Results | Where-Object {
                    $_.Severity -eq 'Warning' -or $_.Severity -eq 'Error'
                }).Count -eq 0) -failureMessage 'One or more ScriptAnalyzer warnings were found. Build cannot continue!'
        }
        default {
            Assert -conditionToCheck ($analysisResult.Count -eq 0) -failureMessage 'One or more ScriptAnalyzer issues were found. Build cannot continue!'
        }
    }
}

# Run Pester tests
# Unit tests: verify inputs / outputs / expected execution path
# Misc tests: verify manifest data, check comment-based help exists
Task 'Test' -depends 'ImportStagingModule' {
    $lines

    # Resolve $TestScripts from $PesterScope here (not in Properties) so that overrides
    # passed via Invoke-psake -properties / build.ps1 -Properties take effect.
    switch ($PesterScope) {
        'CrossPlatform' {
            $TestScripts = Get-ChildItem "$ProjectRoot/Tests/*/*.tests.ps1"
        }
        'WindowsOnly' {
            $TestScripts = Get-ChildItem "$ProjectRoot/Tests/*/*.tests.windows.ps1"
        }
        'All' {
            $TestScripts = Get-ChildItem "$ProjectRoot/Tests/*/*.tests.ps1"
            if ($IsWindows) {
                $TestScripts += Get-ChildItem "$ProjectRoot/Tests/*/*.tests.windows.ps1"
            }
        }
        default {
            Write-Error -Message ('Unknown PesterScope value [{0}] - expected All, CrossPlatform, or WindowsOnly' -f $PesterScope) -ErrorAction Stop
        }
    }

    # Gather test results. Store them in a variable and file
    $TestFilePath = Join-Path -Path $ArtifactFolder -ChildPath $TestFile

    # create a new configuration with our settings
    $PesterConfig = New-PesterConfiguration
    $PesterConfig.TestResult.OutputFormat = 'JUnitXml'
    $PesterConfig.TestResult.OutputPath = $TestFilePath
    $PesterConfig.TestResult.Enabled = $true
    $PesterConfig.Run.PassThru = $true
    $PesterConfig.Run.Path = $TestScripts
    #$PesterConfig.Output.Verbosity = 'Diagnostic'

    $TestResults = Invoke-Pester -Configuration $PesterConfig

    #$TestResults = Invoke-Pester -Script $TestScripts -PassThru -OutputFormat 'NUnitXml' -OutputFile $TestFilePath -PesterOption @{IncludeVSCodeMarker = $true }

    # Fail build on any non-passing result. Discovery errors attach to the
    # container rather than a test, leaving FailedCount at 0.
    if ($TestResults.Result -ne 'Passed') {
        Write-Error "Pester result '$($TestResults.Result)' with '$($TestResults.FailedCount)' failed test(s), build failed"
    }
}

# Create a versioned zip file of all staged files
# NOTE: Admin Rights are needed if you run this locally
Task 'CreateBuildArtifact' -depends 'Init' {
    $lines

    # Create /Release folder
    New-Item -Path $ArtifactFolder -ItemType 'Directory' -Force | Out-String | Write-Verbose

    # Get current manifest version
    try {
        $manifest = Test-ModuleManifest -Path $StagingModuleManifestPath -ErrorAction 'Stop'
        [Version]$manifestVersion = $manifest.Version

    }
    catch {
        throw "Could not get manifest version from [$StagingModuleManifestPath]"
    }

    # Create zip file
    try {
        $releaseFilename = "$($env:BHProjectName)-v$($manifestVersion.ToString()).zip"
        $releasePath = Join-Path -Path $ArtifactFolder -ChildPath $releaseFilename
        Write-Output -InputObject "Creating release artifact [$releasePath] using manifest version [$manifestVersion]"
        Compress-Archive -Path "$StagingFolder/*" -DestinationPath $releasePath -Force -Verbose -ErrorAction 'Stop'
    }
    catch {
        throw "Could not create release artifact [$releasePath] using manifest version [$manifestVersion]"
    }

    Write-Output -InputObject "`nFINISHED: Release artifact creation."
}

# cleanup dirs and files when finished
Task 'Cleanup' {
    $lines

    Write-Output -InputObject 'Cleaning leftover/unneeded artifacts'

    # cleanup
    Remove-Item -Path $ArtifactFolder -Recurse -Force -ErrorAction 'SilentlyContinue'
    Remove-Item -Path $StagingFolder -Recurse -Force -ErrorAction 'SilentlyContinue'
}
