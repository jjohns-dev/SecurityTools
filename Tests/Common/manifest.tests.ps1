BeforeAll {
    $script:manifest = $null
}

Describe 'Module manifest' {
    It 'Has a valid manifest' {
        ($script:manifest = Test-ModuleManifest -Path $env:BHPSModuleManifest -ErrorAction 'Stop' -WarningAction 'SilentlyContinue')
        | Should -Not -BeNullOrEmpty
    }

    It 'Has a valid name in the manifest' {
        $script:manifest.Name | Should -Be $env:BHProjectName
    }

    It 'Has a valid root module' {
        $script:manifest.RootModule | Should -Be "$($env:BHProjectName).psm1"
    }

    It 'Has a valid version in the manifest' {
        $script:manifest.Version -as [Version] | Should -Not -BeNullOrEmpty
    }

    It 'Has a valid description' {
        $script:manifest.Description | Should -Not -BeNullOrEmpty
    }

    It 'Has a valid author' {
        $script:manifest.Author | Should -Not -BeNullOrEmpty
    }

    It 'Has a valid guid' {
        ([guid]::Parse($script:manifest.Guid)) | Should -Not -BeNullOrEmpty
    }

    It 'Has a valid copyright' {
        $script:manifest.CopyRight | Should -Not -BeNullOrEmpty
    }
}
