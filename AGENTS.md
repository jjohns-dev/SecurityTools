# AGENTS.md

PowerShell module of security- and sysadmin-oriented utility functions. Read [CONTRIBUTING.md](CONTRIBUTING.md) for function structure, comment-based help layout, and style rules — this file covers what that guide does not.

## Layout

| Path | Contents |
| ---- | -------- |
| `Public/` | One exported function per file, named `Verb-Noun.ps1`. This is the module's API surface. |
| `Private/` | A mix: `Invoke-DiskCleanup.ps1` (a private helper, dot-sourced but not exported), `.types.ps1xml`/`.format.ps1xml` extensions, and data files (`EventTable.json`, `InformationModel.json`, `windows_signatures_850.csv`) loaded by `SecurityTools.psm1` into read-only module variables. |
| `Tests/Unit/` | One file per public function, `Verb-Noun.tests.ps1`, or `Verb-Noun.tests.windows.ps1` for Windows-only functions. |
| `Tests/Common/` | Help, manifest, and meta tests that run against **every** exported function automatically. |
| `Build/` | psake build (`build.psake.ps1`), entry point (`build.ps1`), analyzer settings, `depend.psd1`. |

Adding a public function means: the `.ps1` in `Public/`, a matching `Tests/Unit/` file, and a `FunctionsToExport` entry in `SecurityTools.psd1`.

## Commands

```pwsh
./Build/build.ps1 -TaskList Analyze                                    # PSScriptAnalyzer
./Build/build.ps1 -TaskList Test -Properties @{ PesterScope = 'All' }  # Pester; All | CrossPlatform | WindowsOnly
./Build/build.ps1 -TaskList Cleanup                                    # delete Staging/ and Artifacts/
```

Add `-ResolveDependency` on a clean checkout. `Analyze` and `Test` both generate `Staging/` and `Artifacts/`; **run `Cleanup` when you are done** — they are gitignored but should not be left behind.

Scanning with `Invoke-ScriptAnalyzer -Path . -Recurse` while `Staging/` exists double-counts every finding in `Public/`, because `Staging/` holds a copy. Clean up first, or read the counts with that in mind.

`.git-blame-ignore-revs` skips the LF renormalization (#163) in blame. GitHub's web UI applies it automatically; local git ignores it until you run `git config blame.ignoreRevsFile .git-blame-ignore-revs` once per clone.

## Tests

Pester 6.2.0+ (upgraded in #145 — see that PR and #138 for the full story of why).

- **`-ForEach` arrays must be populated at discovery time, not run time.** Pester 6 defaults `Run.FailOnNullOrEmptyForEach` to `$true`, and `BeforeAll` runs *after* discovery already needs the array — build `-ForEach` data in `BeforeDiscovery` instead. Getting this wrong doesn't fail a test: it silently drops the whole container's tests with `FailedCount` still `0`, so a green build can mean "collected 10 of 1066 tests." This bit two independent files in this repo (`Tests/Common/Help.Tests.ps1`, `Tests/Unit/Get-StringHash.tests.ps1`) before #145. The build gate is `$TestResults.Result -ne 'Passed'` specifically because `FailedCount` cannot be trusted alone — check `Result`, never just `FailedCount` or a container's own `.Passed`.
- **PowerShell's automatic variables silently shadow same-named locals.** A test fixture hashtable key (or parameter) named `Input`, `Args`, or similar collides with the automatic `$input`/`$args` and the real value never binds — no error, just a value that quietly isn't what you passed. Caught in `Get-StringHash.tests.ps1`, where `-String $Input` had silently never hashed the intended string. If a test's assertions make no sense for what you think you passed, suspect this before suspecting the function under test.
- Import via the BuildHelpers env vars the `Init` task sets: `$env:BHProjectName`, `$env:BHPSModuleManifest`. Do not hard-code the module name.
- Mock anything the function calls with `-ModuleName $env:BHProjectName`, or the real cmdlet runs inside the module.
- CI runs both `ubuntu-latest` (`PesterScope = CrossPlatform`, plain `.tests.ps1` only) and `windows-latest` (`PesterScope = WindowsOnly`, `.tests.windows.ps1` only) — unlike some sibling modules, `.tests.windows.ps1` files really do execute here. Functions needing an RSAT module (`ActiveDirectory`, `GroupPolicy`) still guard with `[bool] (Get-Module -ListAvailable -Name '...')` and `-Skip:(-not $Has...)` rather than relying on the OS split, because RSAT isn't installed on `windows-latest` either — those tests stay (correctly) skipped there too.

## PSScriptAnalyzer

Two different scopes, and confusing them wastes time:

- `Build/build.ps1 -TaskList Analyze` (and CI's `validate` job) analyzes **`Staging/` only**, so no test or build file is ever covered.
- `.github/workflows/pssa-sarif.yml` scans the **whole repo** and feeds the Security tab. It honors `Build/PSScriptAnalyzerSettings.psd1` and `SuppressMessageAttribute`.

Policy: suppress **in place** with `SuppressMessageAttribute` plus a real `Justification`, naming the specific parameter as the attribute's second argument when the rule targets one (e.g. `PSReviewUnusedParameter`), so a new violation elsewhere still fires. `ExcludeRules` in the settings file is reserved for a rule that fires on a uniform, settled API decision across the whole module — currently just `PSAvoidGlobalVars`.

## Versioning and release

`ModuleVersion` in `SecurityTools.psd1` has, in practice, bumped on almost every merged PR regardless of commit type — `feat`, `fix`, `chore`, and `test` commits have all taken a **patch** bump historically. The one **minor** bump on record (`0.9.28` → `0.10.0`) coincided with a brand-new exported function (`Set-GitHubBranchProtection`); a `feat` commit that only adds a parameter to an existing function has still taken a patch bump here. `0.11.0` deviated from that norm deliberately, as a judgment call for a batch covering a whole dead-code directory removal plus a full security-alert cleanup — not the default to reach for.

Merging publishes nothing. `release.yml` is gated on a `v<x.y.z>` tag push on `main`, a separate deliberate step after the version bump lands.

## Merging

The ruleset covers `main` only:

- PR required, all review threads must resolve before merge (code-scanning alerts post as PR review comments — they must resolve, not just the alert closing server-side). Code owner review is on, but 0 approvals are required and `@johnsarie27` is sole code owner, so PRs it authors merge unreviewed (#163: `CLEAN`, empty `reviewDecision`).
- Required status checks: `validate (ubuntu-latest)`, `validate (windows-latest)`.
- Commits must be signed. Squash merge only, so branch commits land on `main` as one new SHA (hence #164). No force-push, no deletion.

Feature branches are unprotected.

**Writing a PR body or commit message that references an issue it does *not* fully close:** GitHub's auto-close keyword match is a dumb substring match on `close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved` immediately followed by `#N` — it does not parse qualifiers or negation. `"Partially closes #141"` and even `"Does not close #141"` both auto-close `#141` on merge anyway. Both happened in this repo. Use `refs #N`, `part of #N`, or `tracked in #N` for a slice PR, and reserve `Closes #N` for the PR that actually finishes it.
