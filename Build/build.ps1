# ==============================================================================
# Filename: build.ps1
# Version:  2.0.2 | Updated: 2026-11-12
# Author:   johnsarie27
# ==============================================================================
<#
.SYNOPSIS
    Runs the shared build harness from pwsh-module-ci against this module.
.DESCRIPTION
    Identical in every consumer repo; do not edit it here. The canonical copy is
    templates/Build/build.ps1 in jjohns-dev/pwsh-module-ci.
    Reads the harness version from this repo's own CI caller, keeps a clone of
    pwsh-module-ci in a per-user cache at that version, and passes every argument
    through to the harness. Local runs therefore use the same harness as CI.
    CI never runs this file: the reusable workflows check out the harness themselves.
.EXAMPLE
    ./Build/build.ps1 -ResolveDependency -TaskList 'Init'
.EXAMPLE
    ./Build/build.ps1 -TaskList 'Test' -Properties @{ PesterScope = 'All' }
#>

$ErrorActionPreference = 'Stop'
$project = Split-Path -Path $PSScriptRoot -Parent
$harnessUrl = 'https://github.com/jjohns-dev/pwsh-module-ci.git'
$cache = Join-Path -Path ([System.Environment]::GetFolderPath('LocalApplicationData')) -ChildPath 'pwsh-module-ci'

# THE VERSION COMES FROM THIS REPO'S CALLER, SO LOCAL AND CI RUN THE SAME HARNESS
$callerPath = Join-Path -Path $project -ChildPath '.github' -AdditionalChildPath 'workflows', 'ci.yml'
$caller = Get-Content -LiteralPath $callerPath -Raw
if ($caller -notmatch 'jjohns-dev/pwsh-module-ci/\.github/workflows/ci\.yml@(\S+)') {
    Write-Error -Message ('No jjohns-dev/pwsh-module-ci ci.yml reference found in [{0}].' -f $callerPath) -ErrorAction 'Stop'
}
$ref = $Matches[1]

if (-not (Test-Path -LiteralPath $cache)) {
    $cloneOutput = git clone --quiet $harnessUrl $cache 2>&1
    if ($LASTEXITCODE -ne 0) {
        $message = 'Could not clone [{0}] into [{1}]. Nothing was run. git said: {2}' -f $harnessUrl, $cache, ($cloneOutput -join ' ')
        Write-Error -Message $message -ErrorAction 'Stop'
    }
}

# A FAILED FETCH MUST STOP THE RUN. UNCHECKED, IT LEAVES THE CACHE AT ITS OLD COMMIT AND THE
# HARNESS RUNS STALE WITH EXIT 0 (MEASURED 2026-11-09). --force: v1/v2 MOVE ON EVERY RELEASE.
$fetchOutput = git -C $cache fetch --quiet --tags --force origin 2>&1
if ($LASTEXITCODE -ne 0) {
    $message = 'Could not update the harness cache [{0}], so its version cannot be trusted. Nothing was run. git said: {1}' -f $cache, ($fetchOutput -join ' ')
    Write-Error -Message $message -ErrorAction 'Stop'
}

$checkoutTarget = $ref
# A BRANCH RESOLVES TO WHAT THE FETCH BROUGHT IN; THE CACHE'S LOCAL BRANCH NEVER ADVANCES (#73)
git -C $cache show-ref --verify --quiet ('refs/remotes/origin/{0}' -f $ref)
if ($LASTEXITCODE -eq 0) { $checkoutTarget = 'origin/{0}' -f $ref }

$checkoutOutput = git -C $cache checkout --quiet --detach $checkoutTarget 2>&1
if ($LASTEXITCODE -ne 0) {
    $message = 'Could not check out pwsh-module-ci at [{0}] in [{1}]. Nothing was run. git said: {2}' -f $ref, $cache, ($checkoutOutput -join ' ')
    Write-Error -Message $message -ErrorAction 'Stop'
}

& (Join-Path -Path $cache -ChildPath 'Build' -AdditionalChildPath 'build.ps1') -ProjectPath $project @args
exit $LASTEXITCODE
