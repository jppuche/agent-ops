<#
.SYNOPSIS
  Closing-line gate for the kit's checked-in roles. Denies / blocks only on a missing close (and,
  for `extractor`, a missing numeric COVERAGE line); any failure of the script itself allows (exit 0).

.DESCRIPTION
  Every kit role ends its report with two lines: `CHECKED:` and `NOT CHECKED:`. Their absence
  means the run is incomplete (system/verification-contract.md, Receiving the output). This
  script makes that check mechanical. One script, two registrations:

  1. PreToolUse, matcher SubagentHandback. If agent_type is a kit role and tool_input.message
     lacks either token, deny the hand-back with a reason telling the agent to finish and close.
     On allow, write the marker <agent_id>.handed in the per-session state dir.
  2. SubagentStop, matcher = the kit role list. If no .handed marker exists for this agent_id,
     stop_hook_active is false, and last_assistant_message lacks either token, return
     decision: block with the same reason.

  Token test: `NOT CHECKED:` present AND a `CHECKED:` not preceded by `NOT ` present (case-
  sensitive). For agent_type `extractor` the report must also contain a coverage line with real
  numbers: `COVERAGE: files requested \d+, files read \d+, rows returned \d+` (case-sensitive;
  the template letters N / M / R or a `<n>` placeholder fail it). Loop guard: at most 2
  denials/blocks per agent_id (counter file, shared by both tests); after that it allows and logs.
  Every deny / block / allow-after-cap is logged as one JSON line (with `missing`: closing,
  coverage or both) to outputs/fanouts/_closing-lines.log; script errors go to
  _closing-lines.errors.log.

  Limit: this catches a MISSING close, not a false "done" - an agent that stopped early can
  still write `NOT CHECKED: none`, and an extractor can still write counts that are wrong; the
  orchestrator compares files read with files requested. It complements, never replaces, the orchestrator's coverage
  checks. It does not see roles dispatched as general-purpose (their agent_type is
  general-purpose). Windows PowerShell 5.1 compatible.
#>
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false
$script:errLog = $null
$script:decLog = $null

$KitRoles = @('fidelity-verifier', 'domain-analyst', 'adversarial-reviewer', 'web-researcher', 'executor', 'operator', 'extractor')
$MaxBlocks = 2
$Reason = 'Your report is missing its closing lines. Finish all the work you were given, then end your report with the two closing lines your role requires: `CHECKED:` (what you verified) and `NOT CHECKED:` (what you could not verify, each with the reason, or `none`).'
$CoverageRoles = @('extractor')
$CoveragePattern = 'COVERAGE: files requested \d+, files read \d+, rows returned \d+'
$CoverageReason = 'Your report is missing its coverage line with real numbers. Count the files you were asked to read, the files you actually read and the rows you returned, and add on its own line: `COVERAGE: files requested <digits>, files read <digits>, rows returned <digits>, files not read: <list or none>` - plain digits, never letters or placeholders. If you have not read every requested file yet, finish reading first.'

function Write-Line([string]$path, [string]$text) {
    if (-not $path) { return }
    $bytes = $utf8.GetBytes($text + [Environment]::NewLine)
    for ($i = 0; $i -lt 40; $i++) {
        try {
            $fs = New-Object System.IO.FileStream($path, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
            try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
            return
        } catch [System.IO.IOException] {
            Start-Sleep -Milliseconds (Get-Random -Minimum 25 -Maximum 125)
        }
    }
}

function Test-Closed([string]$text) {
    if (-not $text) { return $false }
    return ($text -cmatch 'NOT CHECKED:') -and ($text -cmatch '(?<!NOT )CHECKED:')
}

function Test-Coverage([string]$text) {
    if (-not $text) { return $false }
    return ($text -cmatch $CoveragePattern)
}

# Returns the list of missing parts for this agent type: 'closing', 'coverage', both, or none.
function Get-Missing([string]$text, [string]$agentType) {
    $m = @()
    if (-not (Test-Closed $text)) { $m += 'closing' }
    if (($CoverageRoles -contains $agentType) -and -not (Test-Coverage $text)) { $m += 'coverage' }
    return ,$m
}

function Get-Reason($missing) {
    $parts = @()
    if ($missing -contains 'coverage') { $parts += $CoverageReason }
    if ($missing -contains 'closing') { $parts += $Reason }
    elseif ($missing -contains 'coverage') { $parts += 'Then end your report with your closing lines `CHECKED:` and `NOT CHECKED:`.' }
    return ($parts -join ' ')
}

function Write-Decision($j, [string]$action, $missing) {
    try {
        $e = [ordered]@{
            ts         = (Get-Date).ToString('s')
            session_id = [string]$j.session_id
            agent_id   = [string]$j.agent_id
            agent_type = [string]$j.agent_type
            event      = [string]$j.hook_event_name
            action     = $action
            missing    = (@($missing) -join '+')
        }
        Write-Line $script:decLog ($e | ConvertTo-Json -Compress)
    } catch { }
}

try {
    $root = $env:CLAUDE_PROJECT_DIR
    if (-not $root) { $root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
    $dir = Join-Path $root 'outputs/fanouts'
    $script:errLog = Join-Path $dir '_closing-lines.errors.log'
    $script:decLog = Join-Path $dir '_closing-lines.log'

    $raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), $utf8)).ReadToEnd()  # hook input is UTF-8
    if (-not $raw) { exit 0 }
    $j = $raw | ConvertFrom-Json

    $agentType = [string]$j.agent_type
    $agentId   = [string]$j.agent_id
    if ($KitRoles -notcontains $agentType) { exit 0 }   # not a kit role (or main thread): nothing to gate
    if (-not $agentId) { exit 0 }

    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

    # Per-session state dir: the session scratchpad if the hook input names one, else outputs/fanouts/_state/<session_id>/
    if ($j.scratchpad_dir -and (Test-Path -LiteralPath ([string]$j.scratchpad_dir))) {
        $stateDir = Join-Path ([string]$j.scratchpad_dir) 'agent-ops-hooks'
    } else {
        $sid = if ($j.session_id) { ([string]$j.session_id) -replace '[^A-Za-z0-9_.-]', '_' } else { 'no-session' }
        $stateDir = Join-Path $dir (Join-Path '_state' $sid)
    }
    if (-not (Test-Path -LiteralPath $stateDir)) { New-Item -ItemType Directory -Force -Path $stateDir | Out-Null }
    $aidSafe = $agentId -replace '[^A-Za-z0-9_.-]', '_'
    $marker  = Join-Path $stateDir ("$aidSafe.handed")
    $counter = Join-Path $stateDir ("$aidSafe.blocks")

    $count = 0
    if (Test-Path -LiteralPath $counter) {
        $c = ([System.IO.File]::ReadAllText($counter, $utf8)).Trim()
        if ($c -match '^\d+$') { $count = [int]$c }
    }

    $evt = [string]$j.hook_event_name
    if ($evt -eq 'PreToolUse') {
        if ([string]$j.tool_name -ne 'SubagentHandback') { exit 0 }
        $msg = [string]$j.tool_input.message
        $missing = Get-Missing $msg $agentType
        if (($missing.Count -eq 0) -or ($count -ge $MaxBlocks)) {
            if ($missing.Count -gt 0) { Write-Decision $j 'allow-after-cap' $missing }
            [System.IO.File]::WriteAllText($marker, (Get-Date).ToString('s'), $utf8)
            exit 0
        }
        [System.IO.File]::WriteAllText($counter, [string]($count + 1), $utf8)
        Write-Decision $j 'deny' $missing
        $out = [ordered]@{
            hookSpecificOutput = [ordered]@{
                hookEventName            = 'PreToolUse'
                permissionDecision       = 'deny'
                permissionDecisionReason = (Get-Reason $missing)
            }
        }
        [Console]::Out.Write(($out | ConvertTo-Json -Compress -Depth 4))
        exit 0
    }
    elseif ($evt -eq 'SubagentStop') {
        if (Test-Path -LiteralPath $marker) { exit 0 }   # the report went through SubagentHandback and passed there
        if ($j.stop_hook_active -eq $true) { exit 0 }
        $missing = Get-Missing ([string]$j.last_assistant_message) $agentType
        if ($missing.Count -eq 0) { exit 0 }
        if ($count -ge $MaxBlocks) { Write-Decision $j 'allow-after-cap' $missing; exit 0 }
        [System.IO.File]::WriteAllText($counter, [string]($count + 1), $utf8)
        Write-Decision $j 'block' $missing
        $out = [ordered]@{ decision = 'block'; reason = (Get-Reason $missing) }
        [Console]::Out.Write(($out | ConvertTo-Json -Compress))
        exit 0
    }
} catch {
    try {
        if ($script:errLog) {
            $d = Split-Path -Parent $script:errLog
            if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
            Write-Line $script:errLog ((Get-Date).ToString('s') + ' unhandled: ' + $_.Exception.Message)
        }
    } catch { }
}
exit 0
