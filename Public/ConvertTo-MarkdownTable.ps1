function ConvertTo-MarkdownTable {
    <#
    .SYNOPSIS
        Convert array of objects to Markdown table
    .DESCRIPTION
        Convert array of objects to Markdown table
    .PARAMETER InputObject
        Input object.
    .INPUTS
        System.Object.
    .OUTPUTS
        System.String.
    .EXAMPLE
        PS C:\> $svc = Get-Service | Select-Object -Property DisplayName, Name, Description
        PS C:\> $svc | Select-Object -First 5 | ConvertTo-MarkdownTable
        Converts the first 5 services to a Markdown table
    .NOTES
        Status: Stable
        Prior art: answer by Theo, https://stackoverflow.com/a/69011926 (CC BY-SA 4.0)
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, HelpMessage = 'Input object')]
        [ValidateNotNullOrEmpty()]
        [System.Object] $InputObject
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        # COLUMNS ARE TAKEN FROM THE FIRST OBJECT; LATER OBJECTS ARE READ IN THE SAME ORDER
        $columns = $null

        # ESCAPE PIPES SO CELL CONTENT CANNOT SPLIT A COLUMN (SKIP PIPES ALREADY ESCAPED)
        $escape = { param($text) ([System.String] $text) -replace '(?<!\\)\|', '\|' }
    }
    Process {
        if ($null -eq $columns) {
            $columns = @($InputObject.PSObject.Properties.Name)
            '| {0} |' -f (($columns | ForEach-Object -Process { & $escape $_ }) -join ' | ')
            '| {0} |' -f (($columns | ForEach-Object -Process { '-' * $_.Length }) -join ' | ')
        }
        '| {0} |' -f (($columns | ForEach-Object -Process { & $escape $InputObject.$_ }) -join ' | ')
    }
}
