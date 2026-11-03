[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Pester assigns fixtures in BeforeAll and consumes them in It blocks; PSScriptAnalyzer cannot follow that scope.'
)]
Param()

BeforeAll {
    Set-StrictMode -Version latest

    # Make sure MetaFixers.psm1 is loaded - it contains Get-TextFilesList
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'MetaFixers.psm1') -Verbose:$false -Force -ErrorAction 'Stop'

    $projectRoot = $ENV:BHProjectPath
    if (-not $projectRoot) {
        $projectRoot = $PSScriptRoot
    }

    $allTextFiles = Get-TextFilesList -root $projectRoot -notMatch 'Vagrant|Temp'
}

Describe 'Text files formatting' {
    It "Doesn't use Unicode encoding" {
        $unicodeFilesCount = 0
        $allTextFiles | ForEach-Object {
            if (Test-FileUnicode $_) {
                $unicodeFilesCount += 1
                Write-Warning "File $($_.FullName) contains 0x00 bytes. It's probably uses Unicode and need to be converted to UTF-8. Use Fixer 'Get-UnicodeFilesList `$pwd | ConvertTo-UTF8'."
            }
        }
        $unicodeFilesCount | Should -Be 0
    }

    It 'Uses spaces for indentation, not tabs' {
        $totalTabsCount = 0
        $allTextFiles | ForEach-Object {
            $fileName = $_.FullName
                (Get-Content $_.FullName -Raw) | Select-String "`t" | ForEach-Object {
                Write-Warning "There are tab in $fileName. Use Fixer 'Get-TextFilesList `$pwd | ConvertTo-SpaceIndentation'."
                $totalTabsCount++
            }
        }
        $totalTabsCount | Should -Be 0
    }
}
