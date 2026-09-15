# Contributing Guide

- For minor fixes such as a typo, a simple pull request is all that's needed. For more involved changes, please follow the process laid out below.
- :heavy_exclamation_mark: Focus on updating a single function/cmdlet in a Pull Request to make the review processes simpler for the core team.

To propose changes to the existing functions or the creation of a new one, the process is as follows:

1. Create a new [issue](https://github.com/jjohns-dev/SecurityTools/issues/new/choose) using either:
   - The `new_function_proposal` template if you want to propose a new function.
   - The `update_function_proposal` template if you want to modify an existing function.
2. Once the issue has been discussed and approved:
    1. Clone this repository.
    2. Create a new branch.
    3. Either:
        - Create the page using the [new function checklist](#new-function-checklist).
        - Modify the target function in case of an update or refactor.
    4. Submit your [Pull Request](https://help.github.com/articles/creating-a-pull-request/).

## Style Guide

### Content

The intended purpose of the functions in this module is to support information security, digital forensics, and reporting tasks. External module dependencies are kept to a minimum and must be justified — currently the module requires `ImportExcel` (used by the `Export-*` reporting functions) and optionally uses `SqlServer`, `ActiveDirectory`, and `GroupPolicy` for specific Windows-only functions. New dependencies should be discussed in an issue before being added.

### New Function Checklist

- Place the file under `Public/` (exported) or `Private/` (internal use only).
- Name the file `Verb-Noun.ps1`, matching the function name exactly.
- Use only [approved verbs](https://learn.microsoft.com/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands).
- Always include comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.INPUTS`, `.OUTPUTS`, `.EXAMPLE`, `.NOTES`). The `.NOTES` block must include a `Status:` line using one of the following values:

  | Value | Meaning |
  | --- | --- |
  | `Stable` | Production-ready; fully tested and supported |
  | `Beta` | Functional but may have rough edges or limited testing |
  | `Experimental` | Early development; API or behavior may change |
  | `Deprecated` | Still works but will be removed in a future release |
- Add a Pester test under `Tests/Unit/Verb-Noun.tests.ps1`.
- If the function is **exported**, add its name to `FunctionsToExport` in [SecurityTools.psd1](SecurityTools.psd1).
- For Windows-only functions, add a runtime platform guard in the `Begin` block.
- For functions that depend on an optional/external module, call `Import-Module -Name <Name> -ErrorAction Stop` in the `Begin` block (not a script-level `#Requires` for optional dependencies).
- Run Analyze and Test locally before opening the PR (see [How to get started contributing](#how-to-get-started-contributing)).

### Function Template

```powershell
function Verb-Noun {
    <#
    .SYNOPSIS
        One-line summary of what the function does
    .DESCRIPTION
        Longer description of behavior, side effects, and intended use
    .PARAMETER Foo
        Description of the Foo parameter
    .INPUTS
        System.String.
    .OUTPUTS
        System.Object.
    .EXAMPLE
        PS C:\> Verb-Noun -Foo 'bar'
        Explanation of what the example does
    .NOTES
        Status: Stable
        <optional reference links>
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Description of Foo')]
        [ValidateNotNullOrEmpty()]
        [System.String] $Foo
    )
    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.MyCommand)"

        # Platform guard (only for Windows-only functions)
        # if (-not $IsWindows) { Write-Error -Message 'Verb-Noun requires Windows.' -ErrorAction Stop }

        # Optional module import (only for functions with external dependencies)
        # Import-Module -Name SomeModule -ErrorAction Stop
    }
    Process {
        # Function logic here
    }
}
```

### Test Skeleton

```powershell
BeforeDiscovery {
    if (-not (Get-Module -Name $env:BHProjectName)) {
        Import-Module -Name $env:BHPSModuleManifest -ErrorAction 'Stop' -Force
    }
}

Describe -Name 'Verb-Noun' -Fixture {
    Context -Name 'normal usage' -Fixture {
        It -Name 'should not throw for valid input' -Test {
            { Verb-Noun -Foo 'bar' } | Should -Not -Throw
        }
    }
}
```

## How to get started contributing

Follow these steps:

1. Install [Visual Studio Code (VSCode)](https://code.visualstudio.com/).
2. Open this repository folder in VSCode (`File > Open Folder...`).
3. You should be prompted to reopen the folder in a dev container. If you are not prompted, open the Command Palette and run "Dev Containers: Rebuild and Reopen in Container". When complete, you should be connected to the development container as if it was your local machine.
4. You are ready to contribute :+1:

>:alarm_clock: What to verify before pushing the updates?

Ensure your changes are passing PSScriptAnalyzer and Pester tests.

```pwsh
  ./Build/build.ps1 -ResolveDependency -TaskList Test # run pester
  ./Build/build.ps1 -ResolveDependency -TaskList Analyze # run psscriptanalyzer
  ./Build/build.ps1 -ResolveDependency -TaskList Cleanup # cleanup testing artifacts
```

## Pull Requests

Apply one or more labels to your PR at open-time so it is grouped correctly in the auto-generated release notes (configured in [.github/release.yml](.github/release.yml)). Use the label that best describes the user-visible impact:

| Label | Section in release notes |
| --- | --- |
| `breaking` / `breaking-change` | Breaking Changes |
| `enhancement` / `feature` | New Features |
| `bug` / `fix` | Bug Fixes |
| `security` | Security |
| `documentation` / `docs` | Documentation |
| `ci` / `build` / `dependencies` | CI / Build |
| _(none / other)_ | Other Changes |

PRs land in the **first** matching category, so order labels by importance (e.g., a `security` + `bug` PR should be labeled with `security` if you want it to appear there). Apply `ignore-for-release` to omit a PR from the notes entirely.

## Release

This project also includes the necessary tools to automate the release of the module via GitHub Actions. The file [release.yml](.github/workflows/release.yml) handles this task.

To create a new release of the module, first update the module manifest with the necessary version number and commit that to the main branch. Then, create a new tag with the same version number and push it to GitHub. This will start the build process and publish a new version of the module to the repo.
