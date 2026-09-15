function Set-GitHubBranchProtection {
    <#
    .SYNOPSIS
        Apply a standard branch protection policy to a GitHub repository
    .DESCRIPTION
        Applies a standard branch protection policy to the default branch (or a
        named branch) of one or more GitHub repositories owned by the specified
        account. The default policy enforces signed commits, requires linear
        history, blocks force pushes and deletions, requires conversation
        resolution, and prevents administrators from bypassing the rules. These
        controls are designed to limit blast radius if an authentication key or
        token is compromised.

        Requires the GitHub CLI (gh) to be installed and authenticated with an
        admin-scoped token for the target account.
    .PARAMETER Owner
        GitHub account (user or organization) that owns the repositories
    .PARAMETER Repository
        One or more repository names (without the owner prefix). Accepts
        pipeline input.
    .PARAMETER Branch
        Branch to protect. When omitted, the repository's default branch is
        used.
    .PARAMETER RequiredStatusCheck
        Required status check contexts that must pass before merging. Defaults
        to none.
    .PARAMETER Force
        Overwrite an existing rule that differs from the desired policy. Without
        it, a conflicting rule is skipped.
    .INPUTS
        System.String.
    .OUTPUTS
        System.Management.Automation.PSCustomObject.
    .EXAMPLE
        PS C:\> Set-GitHubBranchProtection -Owner 'jjohns-dev' -Repository 'PS.SSL' -WhatIf
        Show what protection would be applied to the default branch of the
        PS.SSL repository without making changes.
    .EXAMPLE
        PS C:\> 'PS.SSL', 'SecurityTools' | Set-GitHubBranchProtection -Owner 'jjohns-dev'
        Apply the standard protection policy to the default branch of two
        repositories via pipeline. Repos whose existing rule already matches
        return 'AlreadyProtected'; repos with a conflicting rule return
        'Conflict' and are skipped.
    .EXAMPLE
        PS C:\> Set-GitHubBranchProtection -Owner 'jjohns-dev' -Repository 'PS.SSL' -Force
        Overwrite any existing (conflicting) rule on the default branch of
        PS.SSL with the standard policy.
    .NOTES
        Status: Stable
        Requires the gh CLI: https://cli.github.com/
        Token must have admin:repo (or equivalent) scope.

        Future considerations (reintroduce when contributor count grows):
        - -ApprovalCount           : required_pull_request_reviews.required_approving_review_count
                                     (raise to >=1 once peer review is expected).
        - -DismissStaleReviews     : required_pull_request_reviews.dismiss_stale_reviews
                                     (set $true so new pushes invalidate prior approvals).
        - -RequireCodeOwnerReview  : required_pull_request_reviews.require_code_owner_reviews
                                     (enable only after a CODEOWNERS file exists AND there
                                     are >=2 owners; otherwise the sole owner cannot merge
                                     their own PRs while enforce_admins is on).
        - -RequireLastPushApproval : required_pull_request_reviews.require_last_push_approval
                                     (set $true to force re-approval after any push from
                                     the PR author).
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param(
        [Parameter(Mandatory, Position = 0, HelpMessage = 'GitHub account owner')]
        [ValidateNotNullOrEmpty()]
        [System.String] $Owner,

        [Parameter(Mandatory, Position = 1, ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Repository name(s)')]
        [ValidateNotNullOrEmpty()]
        [Alias('Name', 'RepositoryName')]
        [System.String[]] $Repository,

        [Parameter(HelpMessage = 'Branch to protect (defaults to repo default branch)')]
        [ValidateNotNullOrEmpty()]
        [System.String] $Branch,

        [Parameter(HelpMessage = 'Required status check contexts')]
        [System.String[]] $RequiredStatusCheck = @(),

        [Parameter(HelpMessage = 'Apply policy even when an existing conflicting rule is present')]
        [System.Management.Automation.SwitchParameter] $Force
    )
    Begin {
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        # VERIFY gh CLI IS AVAILABLE
        if (-not (Get-Command -Name 'gh' -ErrorAction SilentlyContinue)) {
            Write-Error -Message 'gh CLI not found in PATH. Install from https://cli.github.com/.' -ErrorAction Stop
        }

        # VERIFY gh CLI IS AUTHENTICATED
        $null = & gh auth status 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error -Message 'gh CLI is not authenticated. Run: gh auth login --scopes admin:repo_hook,repo' -ErrorAction Stop
        }

        # BUILD PROTECTION PAYLOAD (mirrors the PS.SSL baseline)
        $protectionPayload = [Ordered] @{
            required_status_checks           = [Ordered] @{
                strict   = $true
                contexts = $RequiredStatusCheck
            }
            enforce_admins                   = $true
            required_pull_request_reviews    = [Ordered] @{
                dismiss_stale_reviews           = $false
                require_code_owner_reviews      = $false
                required_approving_review_count = 0
                require_last_push_approval      = $false
            }
            restrictions                     = $null
            required_linear_history          = $true
            allow_force_pushes               = $false
            allow_deletions                  = $false
            block_creations                  = $false
            required_conversation_resolution = $true
            required_signatures              = $true
            lock_branch                      = $false
            allow_fork_syncing               = $false
        }

        # WRITE PAYLOAD TO TEMP FILE (gh api --input requires a file path)
        $payloadPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('gh-branch-protection-{0}.json' -f [System.Guid]::NewGuid())
        $protectionPayload | ConvertTo-Json -Depth 6 | Set-Content -Path $payloadPath -Encoding utf8
        Write-Verbose -Message ('Payload written to: [{0}]' -f $payloadPath)
    }
    Process {
        foreach ($repo in $Repository) {
            $repoFullName = '{0}/{1}' -f $Owner, $repo

            # RESOLVE TARGET BRANCH
            if ($PSBoundParameters.ContainsKey('Branch')) {
                $targetBranch = $Branch
            }
            else {
                Write-Verbose -Message ('Resolving default branch for [{0}]' -f $repoFullName)
                $repoInfo = & gh repo view $repoFullName --json defaultBranchRef 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Error -Message ('[{0}] - failed to query repository: {1}' -f $repoFullName, ($repoInfo -join ' '))
                    continue
                }

                $targetBranch = ($repoInfo | ConvertFrom-Json).defaultBranchRef.name
                if ([System.String]::IsNullOrWhiteSpace($targetBranch)) {
                    Write-Warning -Message ('[{0}] has no default branch - skipping.' -f $repoFullName)
                    continue
                }
            }

            $apiPath = 'repos/{0}/branches/{1}/protection' -f $repoFullName, $targetBranch
            $target = '{0}:{1}' -f $repoFullName, $targetBranch
            $action = 'Apply standard branch protection policy'

            # CHECK FOR EXISTING PROTECTION BEFORE APPLYING
            Write-Verbose -Message ('GET {0}' -f $apiPath)
            $existingRaw = & gh api $apiPath 2>&1
            $hasExisting = ($LASTEXITCODE -eq 0)

            if ($hasExisting) {
                $existing = $existingRaw | ConvertFrom-Json

                # NORMALIZE EXISTING RULE FOR COMPARISON (API returns nested {enabled} wrappers)
                $existingNormalized = [Ordered] @{
                    required_signatures              = [System.Boolean] $existing.required_signatures.enabled
                    enforce_admins                   = [System.Boolean] $existing.enforce_admins.enabled
                    required_linear_history          = [System.Boolean] $existing.required_linear_history.enabled
                    allow_force_pushes               = [System.Boolean] $existing.allow_force_pushes.enabled
                    allow_deletions                  = [System.Boolean] $existing.allow_deletions.enabled
                    required_conversation_resolution = [System.Boolean] $existing.required_conversation_resolution.enabled
                    strict_status_checks             = [System.Boolean] $existing.required_status_checks.strict
                    status_check_contexts            = @($existing.required_status_checks.contexts) -join ','
                    dismiss_stale_reviews            = [System.Boolean] $existing.required_pull_request_reviews.dismiss_stale_reviews
                    require_code_owner_reviews       = [System.Boolean] $existing.required_pull_request_reviews.require_code_owner_reviews
                    required_approving_review_count  = [System.Int32]   $existing.required_pull_request_reviews.required_approving_review_count
                    require_last_push_approval       = [System.Boolean] $existing.required_pull_request_reviews.require_last_push_approval
                }

                # DESIRED RULE IN THE SAME SHAPE FOR APPLES-TO-APPLES COMPARISON
                $desiredNormalized = [Ordered] @{
                    required_signatures              = $true
                    enforce_admins                   = $true
                    required_linear_history          = $true
                    allow_force_pushes               = $false
                    allow_deletions                  = $false
                    required_conversation_resolution = $true
                    strict_status_checks             = $true
                    status_check_contexts            = @($RequiredStatusCheck) -join ','
                    dismiss_stale_reviews            = $false
                    require_code_owner_reviews       = $false
                    required_approving_review_count  = 0
                    require_last_push_approval       = $false
                }

                # DIFF THE TWO
                $differences = foreach ($key in $desiredNormalized.Keys) {
                    if ($existingNormalized[$key] -ne $desiredNormalized[$key]) {
                        '{0} (current=[{1}] desired=[{2}])' -f $key, $existingNormalized[$key], $desiredNormalized[$key]
                    }
                }

                if ($null -eq $differences -or $differences.Count -eq 0) {
                    Write-Verbose -Message ('[{0}] existing rule matches desired policy - skipping.' -f $target)
                    [PSCustomObject] @{
                        Repository = $repoFullName
                        Branch     = $targetBranch
                        Result     = 'AlreadyProtected'
                        Message    = 'Existing rule matches desired policy'
                    }
                    continue
                }

                if (-not $Force) {
                    Write-Warning -Message ('[{0}] existing rule differs from desired policy - skipping. Re-run with -Force to overwrite. Differences: {1}' -f $target, ($differences -join '; '))
                    [PSCustomObject] @{
                        Repository = $repoFullName
                        Branch     = $targetBranch
                        Result     = 'Conflict'
                        Message    = 'Existing rule differs: {0}' -f ($differences -join '; ')
                    }
                    continue
                }

                Write-Verbose -Message ('[{0}] existing rule differs but -Force was specified - overwriting.' -f $target)
            }

            if (-not $PSCmdlet.ShouldProcess($target, $action)) {
                [PSCustomObject] @{
                    Repository = $repoFullName
                    Branch     = $targetBranch
                    Result     = 'Skipped'
                    Message    = 'ShouldProcess declined'
                }
                continue
            }

            Write-Verbose -Message ('PUT {0}' -f $apiPath)
            $applyArgs = @('api', '-X', 'PUT', $apiPath, '--input', $payloadPath)
            $apiOutput = & gh @applyArgs 2>&1

            if ($LASTEXITCODE -ne 0) {
                Write-Error -Message ('[{0}] - gh api PUT failed: {1}' -f $repoFullName, ($apiOutput -join ' '))
                [PSCustomObject] @{
                    Repository = $repoFullName
                    Branch     = $targetBranch
                    Result     = 'Failed'
                    Message    = ($apiOutput -join ' ')
                }
            }
            else {
                [PSCustomObject] @{
                    Repository = $repoFullName
                    Branch     = $targetBranch
                    Result     = 'Protected'
                    Message    = 'Branch protection applied'
                }
            }
        }
    }
    End {
        # CLEANUP TEMP PAYLOAD FILE
        Remove-Item -Path $payloadPath -Force -ErrorAction Ignore
    }
}
