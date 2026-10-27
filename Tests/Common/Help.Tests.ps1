[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Pester assigns fixtures in BeforeDiscovery/BeforeAll and consumes them in It blocks; PSScriptAnalyzer cannot follow that scope.'
)]
Param()

BeforeDiscovery {
    # Taken with love from @juneb_get_help (https://raw.githubusercontent.com/juneb/PesterTDD/master/Module.Help.Tests.ps1)
    # Import module
    if (-not (Get-Module -Name $env:BHProjectName <# -ListAvailable #>)) {
        Import-Module -Name $env:BHPSModuleManifest -ErrorAction 'Stop' #-Force
    }
    # Names, not CommandInfo objects: CommandInfo in -ForEach hangs Pester 6.0.0 (fixed by 6.2.0).
    $Cmdlets = (Get-Command -Module $env:BHProjectName -CommandType 'Cmdlet', 'Function' -ErrorAction 'Stop').Name
}

Describe '<_> help' -ForEach $Cmdlets {
    BeforeDiscovery {
        $Common = 'ProgressAction', 'Debug', 'ErrorAction', 'ErrorVariable', 'InformationAction', 'InformationVariable', 'OutBuffer', 'OutVariable', 'PipelineVariable', 'Verbose', 'WarningAction', 'WarningVariable', 'Confirm', 'Whatif'

        $Command = Get-Command -Name $_ # Get current from -ForEach $Cmdlets in discovery-phase
        $CommandParameters = $Command.ParameterSets.Parameters | Sort-Object -Property Name -Unique | Where-Object { $_.Name -notin $Common } | Select-Object Name
        $CommandParameterNames = $CommandParameters.Name

        # -ForEach is bound at discovery, so help parameter names must resolve here, not only in BeforeAll.
        # Source them from the AST, not Get-Help: Get-Help silently drops a .PARAMETER block that names no real parameter,
        # which makes the matching-help assertion a tautology.
        $HelpContent = if ($Command.ScriptBlock) { $Command.ScriptBlock.Ast.GetHelpContent() }
        $HelpParameterNames = @($HelpContent.Parameters.Keys | Where-Object { $_ -notin $Common })
    }
    BeforeAll {
        $Common = 'ProgressAction', 'Debug', 'ErrorAction', 'ErrorVariable', 'InformationAction', 'InformationVariable', 'OutBuffer', 'OutVariable', 'PipelineVariable', 'Verbose', 'WarningAction', 'WarningVariable', 'Confirm', 'Whatif'

        $Command = Get-Command -Name $_ # Get current from -ForEach $Cmdlets in run-phase
        $CommandParameters = $Command.ParameterSets.Parameters | Sort-Object -Property Name -Unique | Where-Object { $_.Name -notin $Common }# | Select-Object Name
        $CommandParameterNames = $CommandParameters.Name

        $Help = Get-Help $Command -ErrorAction SilentlyContinue
        $HelpParameters = $Help.Parameters.Parameter | Where-Object { $_.Name -notin $Common } | Sort-Object -Property Name -Unique

        # Dynamic parameters are invisible to static Get-Command metadata, so a
        # .PARAMETER block documenting one (e.g. Get-KEVList's -OutputDirectory,
        # gated on -Format) would otherwise look like help for a parameter that
        # does not exist. Re-query with a representative value for each
        # ValidateSet-constrained static parameter to trigger the DynamicParam
        # block, then collect the parameter names it adds.
        $DynamicParameterNames = @()
        if ($Command.ScriptBlock -and $Command.ScriptBlock.Ast.Body.DynamicParamBlock) {
            $Triggers = foreach ($Parameter in $Command.Parameters.Values) {
                if ($Parameter.Name -in $Common) { continue }
                $ValidateSet = $Parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } | Select-Object -First 1
                if ($ValidateSet) { $ValidateSet.ValidValues[0] }
            }
            try {
                $Resolved = Get-Command -Name $Command.Name -ArgumentList $Triggers -ErrorAction Stop
                $DynamicParameterNames = @($Resolved.Parameters.Keys | Where-Object { $_ -notin $CommandParameterNames -and $_ -notin $Common })
            } catch { $DynamicParameterNames = @() }
        }
    }

    # If help is not found, synopsis in auto-generated help is the syntax diagram
    It 'Should not be auto-generated' {
        $Help.Synopsis | Should -Not -Contain 'CommonParameters'
    }

    # Should be a description for every function
    It 'Should have a description' {
        $Help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one example
    It 'Should have at least one example' {
        ($Help.Examples.Example | Select-Object -First 1).Code | Should -Not -BeNullOrEmpty
    }

    # Should be a valid link
    It 'Should have valid link response' {
        if ($Help.relatedLinks.navigationLink.uri) {
            $Results = Invoke-WebRequest -Uri $Help.relatedLinks.navigationLink.uri -UseBasicParsing -TimeoutSec 10
            $Results.StatusCode | Should -Be '200'
        }
    }

    # Should be a description for every parameter
    It 'Should have description for parameter: <_>' -ForEach $CommandParameterNames -AllowNullOrEmptyForEach {
        $CommandParameterName = $_
        $ParameterHelp = $HelpParameters | Where-Object { $_.Name -ieq $CommandParameterName }
        $ParameterHelp.Description.Text | Should -Not -BeNullOrEmpty
    }

    # Required value in Help should match IsMandatory property of parameter
    It 'Should have correct mandatory value for parameter: <_>' -ForEach $CommandParameterNames -AllowNullOrEmptyForEach {
        $CommandParameterName = $_
        $ParameterHelp = $HelpParameters | Where-Object { $_.Name -ieq $CommandParameterName }
        $CodeMandatory = ($Command.ParameterSets.Parameters | Sort-Object -Property Name -Unique | Where-Object { $_.Name -ieq $CommandParameterName }).IsMandatory.toString()
        $ParameterHelp.Required | Should -Be $CodeMandatory
    }

    # Shouldn't find extra parameters in help
    It 'Should have matching help for parameter: <_>' -ForEach $HelpParameterNames -AllowNullOrEmptyForEach {
        $HelpParameterName = $_
        $HelpParameterName -in (@($CommandParameterNames) + @($DynamicParameterNames)) | Should -Be $true
    }
}
