function Test-Performance {
    <#
    .SYNOPSIS
        Test performance of script block
    .DESCRIPTION
        Test performance of script block over given number of executions
    .PARAMETER ScriptBlock
        ScriptBlock to test performance
    .PARAMETER Iterations
        Number of test iterations
    .INPUTS
        None.
    .OUTPUTS
        System.Object[].
    .EXAMPLE
        PS C:\> Test-Performance -ScriptBlock { Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 10 }

        Run ScriptBlock 10 times and returns statistical results as shown below:

        MaxMilliseconds : 3897
        MinMilliseconds : 3756
        AvgMilliseconds : 3824
    .NOTES
        Status: Stable
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, HelpMessage = 'ScriptBlock to test performance')]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.ScriptBlock] $ScriptBlock,

        [Parameter(HelpMessage = 'Number of test iterations')]
        [ValidateRange(3, 10000)]
        [Alias('Runs')]
        [System.Int32] $Iterations = 10
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        # CREATE COLLECTION
        $measurements = [System.Collections.Generic.List[System.TimeSpan]]::new()
    }
    Process {
        # LOOP THROUGH TEST 10 TIMES
        for ($i = 1; $i -LE $Iterations; $i++) {

            # RUN GARBAGE COLLECTION
            [System.GC]::Collect()

            # MEASURE RUN
            $measure = Measure-Command -Expression $ScriptBlock

            # ADD MEASURE TO MEASUREMENT COLLECTION
            $measurements.Add($measure)
        }

        # GET RESULTS
        $results = $measurements | Out-MeasureResult

        # ADD ALL MEASUREMENTS TO RESULTS
        $results | Add-Member -NotePropertyMembers @{ Measurements = $measurements.TotalMilliseconds }

        # RETURN RESULTS
        $results
    }
    End {
        Write-Verbose -Message ('Ending {0}' -f $MyInvocation.MyCommand)
    }
}
