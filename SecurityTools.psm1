# ==============================================================================
# Filename: SecurityTools.psm1
# Author:   Justin Johns
# ==============================================================================

# SET DIRECTORIES
$dirs = @(
    (Join-Path -Path $PSScriptRoot -ChildPath 'Public')
    (Join-Path -Path $PSScriptRoot -ChildPath 'Private')
)

# DOT SOURCE ALL PS SCRIPTS
foreach ($file in (Get-ChildItem -Path $dirs -Filter '*.ps1')) { . $file.FullName }

# SET VARIABLES
New-Variable -Name 'EventTable' -Option ReadOnly -Value (
    Get-Content -Raw -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private/EventTable.json') | ConvertFrom-Json
)
New-Variable -Name 'InfoModel' -Option ReadOnly -Value (
    Get-Content -Raw -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private/InformationModel.json') | ConvertFrom-Json
)
New-Variable -Name 'FileSignatures' -Option ReadOnly -Value (
    Get-Content -Raw -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private/FileSignatures.json') | ConvertFrom-Json
)
New-Variable -Name 'CountryCodes' -Option ReadOnly -Value (
    Import-Csv -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private/ISO-3166.csv')
)

# EXPORT MEMBERS
# Functions are intentionally omitted here. When a module manifest (.psd1) is
# present, FunctionsToExport in the manifest is the authoritative control over
# which functions are visible to the caller after Import-Module. Adding
# -Function * to Export-ModuleMember would be redundant and has no effect when
# the manifest is present. Variables and aliases are still declared here because
# they are not controlled by the manifest in the same way.
Export-ModuleMember -Variable * -Alias *
