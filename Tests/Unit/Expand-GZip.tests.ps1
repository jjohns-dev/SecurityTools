[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseShouldProcessForStateChangingFunctions',
    '',
    Justification = 'New-TestGZipFile is a test fixture helper that writes a throwaway temp file; ShouldProcess support is not meaningful for a test-only helper.'
)]
Param()

BeforeDiscovery {
    if (-not (Get-Module -Name $env:BHProjectName)) {
        Import-Module -Name $env:BHPSModuleManifest -ErrorAction 'Stop' -Force
    }
}

Describe -Name 'Expand-GZip' -Fixture {

    BeforeAll {
        # Helper: write a .gz file with known plaintext contents.
        function New-TestGZipFile {
            param(
                [Parameter(Mandatory)] [string] $Path,
                [Parameter(Mandatory)] [string] $Content
            )
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
            $fs = [System.IO.File]::Create($Path)
            try {
                $gz = New-Object System.IO.Compression.GZipStream($fs, [System.IO.Compression.CompressionMode]::Compress)
                try { $gz.Write($bytes, 0, $bytes.Length) } finally { $gz.Dispose() }
            }
            finally { $fs.Dispose() }
        }
    }

    Context -Name 'normal usage' -Fixture {
        BeforeEach {
            # Use $TestDrive (real filesystem path) rather than the 'TestDrive:' PSDrive,
            # because Expand-GZip passes the path to .NET FileStream which does not resolve PSDrives.
            $script:Plaintext = 'hello gzip world'
            $script:SourcePath = Join-Path -Path $TestDrive -ChildPath 'sample.txt.gz'
            $script:DestPath = Join-Path -Path $TestDrive -ChildPath 'sample.txt'
            New-TestGZipFile -Path $script:SourcePath -Content $script:Plaintext
            # Clean any leftover destination from a previous It in this Context.
            if (Test-Path -Path $script:DestPath) { Remove-Item -Path $script:DestPath -Force }
        }

        It -Name 'expands to the source directory when -OutputDirectory is omitted' -Test {
            Expand-GZip -Path $script:SourcePath
            $expected = Join-Path -Path $TestDrive -ChildPath 'sample.txt'
            Test-Path -Path $expected -PathType Leaf | Should -BeTrue
            (Get-Content -Path $expected -Raw) | Should -Be $script:Plaintext
        }

        It -Name 'expands to the specified -OutputDirectory' -Test {
            $destDir = Join-Path -Path $TestDrive -ChildPath 'out'
            New-Item -Path $destDir -ItemType Directory | Out-Null
            Expand-GZip -Path $script:SourcePath -OutputDirectory $destDir
            $expected = Join-Path -Path $destDir -ChildPath 'sample.txt'
            Test-Path -Path $expected -PathType Leaf | Should -BeTrue
            (Get-Content -Path $expected -Raw) | Should -Be $script:Plaintext
        }

        It -Name 'should not throw for a valid .gz file' -Test {
            { Expand-GZip -Path $script:SourcePath } | Should -Not -Throw
        }
    }

    Context -Name 'parameter validation' -Fixture {
        It -Name 'rejects a path that does not exist' -Test {
            $missing = Join-Path -Path $TestDrive -ChildPath 'does-not-exist.gz'
            { Expand-GZip -Path $missing } | Should -Throw
        }

        It -Name 'rejects a file without a .gz extension' -Test {
            $nonGz = Join-Path -Path $TestDrive -ChildPath 'plain.txt'
            Set-Content -Path $nonGz -Value 'not gzipped'
            { Expand-GZip -Path $nonGz } | Should -Throw
        }

        It -Name 'rejects an -OutputDirectory that does not exist' -Test {
            $src = Join-Path -Path $TestDrive -ChildPath 'src.txt.gz'
            New-TestGZipFile -Path $src -Content 'data'
            $badDir = Join-Path -Path $TestDrive -ChildPath 'no-such-dir'
            { Expand-GZip -Path $src -OutputDirectory $badDir } | Should -Throw
        }

        It -Name 'does not accept -DestinationPath (alias intentionally absent)' -Test {
            $src = Join-Path -Path $TestDrive -ChildPath 'alias.txt.gz'
            New-TestGZipFile -Path $src -Content 'data'
            $destDir = Join-Path -Path $TestDrive -ChildPath 'dest'
            New-Item -Path $destDir -ItemType Directory | Out-Null
            { Expand-GZip -Path $src -DestinationPath $destDir } | Should -Throw
        }
    }

    Context -Name 'content fidelity' -Fixture {
        It -Name 'expands payloads larger than a single small read buffer' -Test {
            # 5000-char payload exceeds a single small read, guarding against truncated copies.
            $payload = -join (1..5000 | ForEach-Object { [char](65 + ($_ % 26)) })
            $src = Join-Path -Path $TestDrive -ChildPath 'large.txt.gz'
            New-TestGZipFile -Path $src -Content $payload

            Expand-GZip -Path $src
            $expected = Join-Path -Path $TestDrive -ChildPath 'large.txt'
            (Get-Content -Path $expected -Raw) | Should -Be $payload
        }

        It -Name 'strips only the final .gz extension for multi-dot filenames' -Test {
            # archive.tar.gz should expand to archive.tar
            $src = Join-Path -Path $TestDrive -ChildPath 'archive.tar.gz'
            New-TestGZipFile -Path $src -Content 'tar-payload'

            Expand-GZip -Path $src
            $expected = Join-Path -Path $TestDrive -ChildPath 'archive.tar'
            Test-Path -Path $expected -PathType Leaf | Should -BeTrue
        }

        It -Name 'roundtrips arbitrary binary bytes' -Test {
            $bytes = [byte[]]@(0, 1, 2, 3, 127, 128, 200, 255, 0, 42)
            $src = Join-Path -Path $TestDrive -ChildPath 'binary.bin.gz'

            # Write a gzip stream of raw bytes (bypassing the UTF-8 helper).
            $fs = [System.IO.File]::Create($src)
            try {
                $gz = New-Object System.IO.Compression.GZipStream($fs, [System.IO.Compression.CompressionMode]::Compress)
                try { $gz.Write($bytes, 0, $bytes.Length) } finally { $gz.Dispose() }
            }
            finally { $fs.Dispose() }

            Expand-GZip -Path $src
            $expected = Join-Path -Path $TestDrive -ChildPath 'binary.bin'
            $actual = [System.IO.File]::ReadAllBytes($expected)
            $actual | Should -Be $bytes
        }
    }

    Context -Name 'behavior contracts' -Fixture {
        It -Name 'refuses to overwrite an existing destination file without -Force' -Test {
            $src = Join-Path -Path $TestDrive -ChildPath 'no-overwrite.txt.gz'
            New-TestGZipFile -Path $src -Content 'new contents'
            $dest = Join-Path -Path $TestDrive -ChildPath 'no-overwrite.txt'
            Set-Content -Path $dest -Value 'pre-existing'

            { Expand-GZip -Path $src } | Should -Throw -ExpectedMessage '*already exists*'
            (Get-Content -Path $dest -Raw) | Should -Be "pre-existing$([Environment]::NewLine)"
        }

        It -Name 'overwrites an existing destination file when -Force is passed' -Test {
            $src = Join-Path -Path $TestDrive -ChildPath 'overwrite.txt.gz'
            New-TestGZipFile -Path $src -Content 'new contents'
            $dest = Join-Path -Path $TestDrive -ChildPath 'overwrite.txt'
            Set-Content -Path $dest -Value 'pre-existing junk that is much longer than the replacement payload'

            Expand-GZip -Path $src -Force
            (Get-Content -Path $dest -Raw) | Should -Be 'new contents'
        }

        It -Name '-WhatIf produces no destination file' -Test {
            $src = Join-Path -Path $TestDrive -ChildPath 'whatif.txt.gz'
            New-TestGZipFile -Path $src -Content 'data'
            $dest = Join-Path -Path $TestDrive -ChildPath 'whatif.txt'

            Expand-GZip -Path $src -WhatIf
            Test-Path -Path $dest | Should -BeFalse
        }

        It -Name 'produces no pipeline output' -Test {
            $src = Join-Path -Path $TestDrive -ChildPath 'silent.txt.gz'
            New-TestGZipFile -Path $src -Content 'data'
            $result = Expand-GZip -Path $src
            $result | Should -BeNullOrEmpty
        }
    }
}
