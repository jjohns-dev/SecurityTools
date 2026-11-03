function Get-SavedHistory {
    <#
    .SYNOPSIS
        Find command matching search term(s)
    .DESCRIPTION
        Search for commands in the stored session history for PowerShell that
        match the provided keyword(s). If no keywards are provided all unique
        commands will be returned.
    .PARAMETER Search
        Search term or phrase (best results with a contiguous phrase)
    .INPUTS
        System.String.
    .OUTPUTS
        System.Object[].
    .EXAMPLE
        PS C:\> Get-SavedHistory -Search "Invoke-RestMethod -Uri"
        Returns all unique commands matching the search phrase from PSReadLine history
    .NOTES
        Status: Stable
        https://serverfault.com/questions/891265/how-to-search-powershell-command-history-from-previous-sessions
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        'Search',
        Justification = 'Used inside the $where scriptblock, which the analyzer does not trace into.'
    )]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Search phrase')]
        [ValidateNotNullOrEmpty()]
        [System.String] $Search
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        $where = { $_ -like ('*{0}*' -f $Search) -and $_ -notmatch 'HistorySavePath' -and $_ -notmatch 'SavedHistory' }
        $history = Get-Content -Path (Get-PSReadLineOption).HistorySavePath |
            Where-Object -FilterScript $where | Select-Object -Unique
    }
    Process {
        for ($i = 0; $i -lt $history.Count; $i++) {
            [PSCustomObject] @{
                Id          = ($i + 1)
                CommandLine = $history[$i]
            }
        }
    }
}
