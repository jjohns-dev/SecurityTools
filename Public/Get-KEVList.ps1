function Get-KEVList {
    <#
    .SYNOPSIS
        Get Known Exploited Vulnerability list
    .DESCRIPTION
        Get Known Exploited Vulnerabilities as array of objects or download as
        CSV or JSON file
    .PARAMETER Format
        Format to download catalog
    .PARAMETER OutputDirectory
        Output Directory
    .INPUTS
        None.
    .OUTPUTS
        None.
    .EXAMPLE
        PS C:\> Get-KEVList
        Returns an object containing known exploited vulnerability catalog
    .NOTES
        Status: Stable
        https://cyber.dhs.gov/bod/22-01/
        https://www.cisa.gov/known-exploited-vulnerabilities
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, HelpMessage = 'Format to download catalog')]
        [ValidateSet('CSV', 'JSON', 'Schema')]
        [System.String] $Format
    )
    DynamicParam {
        if ($PSBoundParameters.ContainsKey('Format')) {
            # SET DYNAMIC PARAMETERS
            $dynamicParams = @{
                OutputDirectory = @{
                    Type       = 'System.String'
                    Attributes = @{
                        Mandatory   = $true
                        HelpMessage = 'Output directory'
                    }
                }
            }

            # CREATE PARAMETER DICTIONARY
            $paramDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()

            # CREATE OBJECTS
            foreach ($param in $dynamicParams.GetEnumerator()) {
                # CREATE ATTRIBUTE OBJECT
                $paramAttribute = [System.Management.Automation.ParameterAttribute]::new()

                # POPULATE COLLECTION WITH ATTRIBUTES
                foreach ($attribute in $param.Value['Attributes'].GetEnumerator()) {
                    $paramAttribute.($attribute.Key) = $attribute.Value
                }

                # CREATE COLLECTION
                $attrCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
                $attrCollection.Add($paramAttribute)

                # CREATE RUNTIMEDEFINEDPARAMETER OBJECT
                $parameter = [System.Management.Automation.RuntimeDefinedParameter]::new(
                    $param.Key, $param.Value['Type'], $attrCollection
                )

                # ADD PARAMETER TO DICTIONARY
                $paramDictionary.Add($param.Key, $parameter)
            }

            # RETURN PARAMETER DICTIONARY
            return $paramDictionary
        }
    }
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        # VALIDATE OUTPUTDIRECTORY PARAMETER
        if ($PSBoundParameters.ContainsKey('OutputDirectory')) {
            if (-Not (Test-Path -Path $PSBoundParameters.OutputDirectory -PathType Container)) {
                Write-Error -Message ('Invalid output directory "{0}"' -f $PSBoundParameters.OutputDirectory) -ErrorAction Stop
            }
        }
    }
    Process {
        if ($PSBoundParameters.ContainsKey('Format')) {
            # SET URI
            $uri = switch ($Format) {
                'CSV' { 'https://www.cisa.gov/sites/default/files/csv/known_exploited_vulnerabilities.csv' }
                'JSON' { 'https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json' }
                'Schema' { 'https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities_schema.json' }
            }

            # SET OUTPUT PATH
            $outFile = Join-Path -Path $PSBoundParameters['OutputDirectory'] -ChildPath (Split-Path -Path $uri -Leaf)

            # DOWNLOAD CSV FILE
            Invoke-WebRequest -Uri $uri -OutFile $outFile
        }
        else {
            # SET URI
            $uri = 'https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json'

            # GET KNOWN EXPLOITED VULNERABILITIES
            Invoke-RestMethod -Uri $uri
        }
    }
}
