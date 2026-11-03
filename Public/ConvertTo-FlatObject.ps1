function ConvertTo-FlatObject {
    <#
    .SYNOPSIS
        Flattens a nested object into a single level object
    .DESCRIPTION
        Flattens a nested object into a single level object. Nested property names, dictionary keys and array
        indexes are joined with a separator to form each flat property name.
    .PARAMETER Object
        The object to be flattened
    .PARAMETER Separator
        The separator used between the recursive property names
    .PARAMETER Base
        The first index name of an embedded array:
        - 1, arrays will be 1 based: <Parent>.1, <Parent>.2, <Parent>.3, ...
        - 0, arrays will be 0 based: <Parent>.0, <Parent>.1, <Parent>.2, ...
        - "", the first item in an array will be unnamed and then followed with 1: <Parent>, <Parent>.1, <Parent>.2, ...
    .PARAMETER Depth
        The maximum number of levels to flatten. Values nested deeper are kept as-is. Any negative value removes the
        limit, which can loop forever on an object that references itself.
    .PARAMETER ExcludeProperty
        Property or dictionary key names to exclude, at any level
    .INPUTS
        System.Object.
    .OUTPUTS
        System.Management.Automation.PSCustomObject.
    .EXAMPLE
        PS C:\> Get-Process | ConvertTo-FlatObject
        Flattens all process objects into single-level objects with dot-separated property names.
    .NOTES
        Status: Stable
        Prior art: Flatten-Object by Ronald Bode (iRon), https://stackoverflow.com/a/24854277 (CC BY-SA 4.0), and
        ConvertTo-FlatObject in PSSharedGoods by Evotec, https://github.com/EvotecIT/PSSharedGoods (MIT)
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeLine, HelpMessage = 'Object to convert')]
        [System.Object[]] $Object,

        [Parameter(HelpMessage = 'Separator character')]
        [System.String] $Separator = ".",

        [Parameter(HelpMessage = 'Base')]
        [ValidateSet("", 0, 1)]
        [System.Object] $Base = 0,

        [Parameter(HelpMessage = 'Depth')]
        [System.Int16] $Depth = 5,

        [Parameter(HelpMessage = 'Property to exclude')]
        [System.String[]] $ExcludeProperty
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        # VALUES OF THESE TYPES ARE WRITTEN AS STRINGS RATHER THAN EXPANDED
        $stringTypes = [System.String], [System.DateTime], [System.TimeSpan], [System.Version], [System.Enum]

        # "-Base ''" LEAVES THE FIRST ARRAY ITEM UNNAMED; COMPARE AS A STRING BECAUSE 0 -eq '' IS TRUE
        $unnamedFirst = "$Base" -eq ''
        $offset = if ($unnamedFirst) { 0 } else { [System.Int32] $Base }

        # RECURSIVELY WRITE EACH LEAF VALUE INTO $Output UNDER ITS JOINED PATH
        function Add-FlatValue {
            Param(
                $Value, [System.String[]] $Path, [System.Int32] $Levels, [System.Collections.IDictionary] $Output,
                [System.String] $Join, [System.String[]] $Exclude
            )

            $children = [ordered] @{}
            $isLeaf = $true

            if ($null -eq $Value) {
                # NULL IS A LEAF
            }
            elseif ($stringTypes.Where({ $Value -is $_ }, 'First')) {
                $Value = $Value.ToString()
            }
            elseif ($Levels -ne 0 -and $Value -is [System.Collections.IDictionary]) {
                $isLeaf = $false
                if ($Value.Count -eq 0) { $Value = $null; $isLeaf = $true }
                foreach ($key in $Value.Keys) { $children["$key"] = $Value[$key] }
            }
            elseif ($Levels -ne 0 -and $Value -is [System.Collections.IEnumerable]) {
                $index = 0
                foreach ($item in $Value) {
                    $name = if ($unnamedFirst -and $index -eq 0) { '' } else { [System.String] ($index + $offset) }
                    $children[$name] = $item
                    $index++
                }
                $isLeaf = $index -eq 0
            }
            elseif ($Levels -ne 0) {
                foreach ($prop in $Value.PSObject.Properties) {
                    if ($prop.IsGettable) { $children[$prop.Name] = $Value.($prop.Name) }
                }
                $isLeaf = $children.Count -eq 0
            }

            if ($isLeaf) {
                # A ROOT VALUE WITH NOTHING TO EXPAND HAS NO PATH AND PRODUCES NO PROPERTY
                $name = ($Path.Where({ $_ -ne '' })) -join $Join
                if ($name) { $Output[$name] = $Value }
                return
            }

            foreach ($key in $children.Keys) {
                if ($key -in $Exclude) { continue }
                $childParams = @{
                    Value   = $children[$key]
                    Path    = $Path + $key
                    Levels  = $Levels - 1
                    Output  = $Output
                    Join    = $Join
                    Exclude = $Exclude
                }
                Add-FlatValue @childParams
            }
        }
    }
    Process {
        foreach ($o in $Object) {
            if ($null -eq $o) { continue }
            $flat = [ordered] @{}
            Add-FlatValue -Value $o -Path @() -Levels $Depth -Output $flat -Join $Separator -Exclude $ExcludeProperty
            [PSCustomObject] $flat
        }
    }
}
