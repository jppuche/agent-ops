<#
.SYNOPSIS
  Logs per-request token usage of every finished subagent. Non-blocking (always exits 0).

.DESCRIPTION
  SubagentStop hook (all agent types, registered with async: true). Reads the hook JSON from
  stdin, waits briefly for the subagent transcript to flush (the transcript is written
  asynchronously), then streams it line by line and parses only assistant records that carry
  message.usage - a cheap string pre-filter runs first, so large tool-result lines are never
  handed to ConvertFrom-Json.

  Records of one API request share a requestId and earlier records carry partial
  output_tokens, so usage is grouped by requestId and each field keeps its MAX.

  Appends one JSON line per request to outputs/fanouts/_subagent-usage.jsonl:
    ts (timestamp of the request's last transcript record), session_id, agent_id, agent_type,
    request_id, model, effort (the record's top-level key; null if absent), input, output,
    cache_read, cache_creation, cache_creation_5m, cache_creation_1h (null if the split is
    absent), prompt_tokens (= input + cache_read + cache_creation), over_100k (informative:
    some models price prompts over 100K tokens higher), stop_reason, internal (agent_type
    empty, or no .meta.json sidecar beside the transcript - Agent-tool subagents always have
    one; the session's own --agent name is not in the SubagentStop input).

  Idempotent: a per-agent index of logged request ids (in the session scratchpad if the
  hook input names one, else outputs/fanouts/_state/<session_id>/) makes a resumed agent's
  second SubagentStop add only new requests. Analysis can also dedupe on request_id.

  Never blocks: any error is appended to outputs/fanouts/_subagent-usage.errors.log and the
  script exits 0. One exception is silent by design: a transcript still missing after the wait
  is an error only for a kit role; for any other agent type (or an empty one - Claude Code's
  internal agents often write no transcript) the script exits quietly. Writes are UTF-8 without BOM, appended with a retry loop (parallel agents
  finish together). Windows PowerShell 5.1 compatible.
#>
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false
$script:errLog = $null

# Kit roles (same list as check-closing-lines.ps1 and the settings.hooks.json matcher).
$KitRoles = @('fidelity-verifier', 'domain-analyst', 'adversarial-reviewer', 'web-researcher', 'executor', 'operator', 'extractor')

function Write-HookError([string]$msg) {
    try {
        if ($script:errLog) {
            [System.IO.File]::AppendAllText($script:errLog, ((Get-Date).ToString('s') + ' ' + $msg + [Environment]::NewLine), $utf8)
        }
    } catch { }
}

function Add-Lines([string]$path, [string]$text) {
    # Append with retry: parallel agents can stop together and contend for the same file.
    $bytes = $utf8.GetBytes($text)
    for ($i = 0; $i -lt 40; $i++) {
        try {
            $fs = New-Object System.IO.FileStream($path, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
            try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
            return
        } catch [System.IO.IOException] {
            Start-Sleep -Milliseconds (Get-Random -Minimum 25 -Maximum 125)
        }
    }
    throw "could not append to $path after 40 attempts"
}

function Get-MaxInt($current, $value) {
    if ($null -eq $value) { return $current }
    $v = [long]$value
    if ($null -eq $current -or $v -gt $current) { return $v }
    return $current
}

try {
    $raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), $utf8)).ReadToEnd()  # hook input is UTF-8; [Console]::In would decode it with the OEM code page
    if (-not $raw) { exit 0 }

    $root = $env:CLAUDE_PROJECT_DIR
    if (-not $root) { $root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
    $dir = Join-Path $root 'outputs/fanouts'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $script:errLog = Join-Path $dir '_subagent-usage.errors.log'
    $logPath = Join-Path $dir '_subagent-usage.jsonl'

    $j = $raw | ConvertFrom-Json
    $sessionId = [string]$j.session_id
    $agentId   = [string]$j.agent_id
    $agentType = [string]$j.agent_type

    # --- resolve the transcript path (expand a leading ~) ---
    $tp = [string]$j.agent_transcript_path
    if (-not $tp) { Write-HookError "no agent_transcript_path (agent_id=$agentId, agent_type=$agentType)"; exit 0 }
    if ($tp -eq '~' -or $tp -match '^~[\\/]') {
        $userHome = [Environment]::GetFolderPath('UserProfile')
        $tp = if ($tp.Length -gt 2) { Join-Path $userHome $tp.Substring(2) } else { $userHome }
    }

    # --- wait for the transcript to flush: poll up to ~3 s for its size to stop changing ---
    $prev = -1L
    for ($i = 0; $i -lt 12; $i++) {
        if (Test-Path -LiteralPath $tp) {
            $len = (Get-Item -LiteralPath $tp).Length
            if ($len -gt 0 -and $len -eq $prev) { break }
            $prev = $len
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not (Test-Path -LiteralPath $tp)) {
        # Agents Claude Code runs for its own features often have no transcript: not an error.
        # A kit role without one is, because its cost is what the log exists to price.
        if ($KitRoles -contains $agentType) { Write-HookError "transcript not found after wait: $tp (agent_id=$agentId, agent_type=$agentType)" }
        exit 0
    }

    # --- internal-agent flag: Agent-tool subagents always have a .meta.json sidecar ---
    $metaPath = [System.IO.Path]::ChangeExtension($tp, '.meta.json')
    $internal = ([string]::IsNullOrEmpty($agentType)) -or (-not (Test-Path -LiteralPath $metaPath))

    # --- stream the transcript; group usage by requestId keeping the max of each field ---
    $requests = [ordered]@{}
    $unparsed = 0
    $fs = New-Object System.IO.FileStream($tp, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
    $reader = New-Object System.IO.StreamReader($fs, $utf8)
    try {
        while ($null -ne ($line = $reader.ReadLine())) {
            if ($line.IndexOf('"type":"assistant"', [System.StringComparison]::Ordinal) -lt 0) { continue }
            if ($line.IndexOf('"usage":', [System.StringComparison]::Ordinal) -lt 0) { continue }
            try { $r = $line | ConvertFrom-Json } catch { $unparsed++; continue }
            if ($r.type -ne 'assistant' -or $null -eq $r.message -or $null -eq $r.message.usage) { continue }
            $rid = [string]$r.requestId
            if (-not $rid) { $rid = [string]$r.message.id }
            if (-not $rid) { continue }
            $u = $r.message.usage
            if (-not $requests.Contains($rid)) {
                $requests[$rid] = [ordered]@{ ts = $null; model = $null; effort = $null; input = $null; output = $null; cache_read = $null; cache_creation = $null; cache_creation_5m = $null; cache_creation_1h = $null; stop_reason = $null }
            }
            $q = $requests[$rid]
            if ($r.timestamp) { $q.ts = [string]$r.timestamp }
            if ($r.message.model) { $q.model = [string]$r.message.model }
            if ($r.effort) { $q.effort = [string]$r.effort }
            if ($r.message.stop_reason) { $q.stop_reason = [string]$r.message.stop_reason }
            $q.input          = Get-MaxInt $q.input          $u.input_tokens
            $q.output         = Get-MaxInt $q.output         $u.output_tokens
            $q.cache_read     = Get-MaxInt $q.cache_read     $u.cache_read_input_tokens
            $q.cache_creation = Get-MaxInt $q.cache_creation $u.cache_creation_input_tokens
            if ($null -ne $u.cache_creation) {
                $q.cache_creation_5m = Get-MaxInt $q.cache_creation_5m $u.cache_creation.ephemeral_5m_input_tokens
                $q.cache_creation_1h = Get-MaxInt $q.cache_creation_1h $u.cache_creation.ephemeral_1h_input_tokens
            }
        }
    } finally { $reader.Dispose() }
    if ($unparsed -gt 0) { Write-HookError "$unparsed usage line(s) could not be parsed in $tp (agent_id=$agentId)" }
    if ($requests.Count -eq 0) { exit 0 }

    # --- idempotency: per-agent index of request ids already logged ---
    $stateDir = $null
    if ($j.scratchpad_dir -and (Test-Path -LiteralPath ([string]$j.scratchpad_dir))) {
        $stateDir = Join-Path ([string]$j.scratchpad_dir) 'agent-ops-hooks'
    } else {
        $sid = if ($sessionId) { $sessionId -replace '[^A-Za-z0-9_.-]', '_' } else { 'no-session' }
        $stateDir = Join-Path $dir (Join-Path '_state' $sid)
    }
    if (-not (Test-Path -LiteralPath $stateDir)) { New-Item -ItemType Directory -Force -Path $stateDir | Out-Null }
    $aidSafe = if ($agentId) { $agentId -replace '[^A-Za-z0-9_.-]', '_' } else { 'no-agent-id' }
    $indexPath = Join-Path $stateDir ("usage-$aidSafe.idx")
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    if (Test-Path -LiteralPath $indexPath) {
        foreach ($l in [System.IO.File]::ReadAllLines($indexPath, $utf8)) { if ($l) { [void]$seen.Add($l.Trim()) } }
    }

    $sb = New-Object System.Text.StringBuilder
    $newIds = New-Object System.Text.StringBuilder
    foreach ($rid in $requests.Keys) {
        if ($seen.Contains($rid)) { continue }
        $q = $requests[$rid]
        $in = if ($null -ne $q.input) { $q.input } else { 0 }
        $cr = if ($null -ne $q.cache_read) { $q.cache_read } else { 0 }
        $cc = if ($null -ne $q.cache_creation) { $q.cache_creation } else { 0 }
        $prompt = $in + $cr + $cc
        $entry = [ordered]@{
            ts                = $q.ts
            session_id        = $sessionId
            agent_id          = $agentId
            agent_type        = $agentType
            request_id        = $rid
            model             = $q.model
            effort            = $q.effort
            input             = $q.input
            output            = $q.output
            cache_read        = $q.cache_read
            cache_creation    = $q.cache_creation
            cache_creation_5m = $q.cache_creation_5m
            cache_creation_1h = $q.cache_creation_1h
            prompt_tokens     = $prompt
            over_100k         = ($prompt -gt 100000)
            stop_reason       = $q.stop_reason
            internal          = $internal
        }
        [void]$sb.Append(($entry | ConvertTo-Json -Compress -Depth 4)).Append([Environment]::NewLine)
        [void]$newIds.Append($rid).Append([Environment]::NewLine)
    }
    if ($sb.Length -gt 0) {
        Add-Lines $logPath $sb.ToString()
        Add-Lines $indexPath $newIds.ToString()
    }
} catch {
    Write-HookError ("unhandled: " + $_.Exception.Message)
}
exit 0
