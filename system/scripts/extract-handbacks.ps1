<#
.SYNOPSIS
  Files subagent hand-backs (and each subagent's first prompt) from Claude Code's transcripts
  into outputs/fanouts/_handbacks/<session-id>/. Opt-in, run by hand. Not a hook.

.DESCRIPTION
  Why: the harness may keep no usable copy of a hand-back. Observed 2026-11-13/14 (one machine, one
  Claude Code build): the task .output files of background subagents were empty, and the hand-backs
  had to be recovered from the subagent transcripts. This script does that recovery in one command.

  Source: ~/.claude/projects/<project-slug>/<session-id>/subagents/agent-<id>.jsonl, where the slug is
  the project path with every character outside [A-Za-z0-9] replaced by '-'. For each transcript:
    - prompt: the first user record's text (the prompt the subagent was dispatched with);
    - output: the `message` input of the last SubagentHandback tool call whose result was not an
      error (a hook such as check-closing-lines.ps1 denies incomplete ones); if every call was
      denied, the last one, labelled as denied; when the transcript has none (older builds, or an
      agent that ended without one), the last assistant text, labelled as such.
  The sidecar agent-<id>.meta.json, when present, supplies agentType, description, model and effort.
  An agent whose sidecar does not say finished: true is still running: it is skipped, so no partial
  result is filed as if final. Run the script again when the fan-out is done.

  Writes, per agent: <agent-id>__prompt.md and <agent-id>__output.md (names check-docs.ps1 treats as
  verbatim archives). Existing files are skipped unless -Force. Prints only ids, counts and paths,
  never message text. Transcripts are opened with shared read/write access (Claude Code may still
  hold them open).

  Secrets: text that matches common credential shapes (API keys and tokens of several vendors, bearer
  tokens, credentials in URLs, private key blocks, JWTs, `password=` / `api_key:` style assignments)
  is replaced by [REDACTED:<kind>] before it is written, in the header fields too; the count is printed
  and recorded in the file header. Pattern matching misses what it does not know: review a file before
  you commit or share it. The output folder is gitignored by the kit's .gitignore; move what an audit
  needs into outputs/fanouts/<ticket>-<stage>/.

  Read-only on the transcripts. A line or file it cannot parse is skipped and counted. Windows
  PowerShell 5.1 compatible.

.PARAMETER SessionId
  Session to extract. Default: the session whose newest subagent transcript is the most recent.

.PARAMETER All
  Extract every session of this project that has subagents.

.PARAMETER ProjectDir
  Project root. Default: CLAUDE_PROJECT_DIR, else resolved from this script's location.

.PARAMETER TranscriptRoot
  Folder that holds the project's session folders. Default: ~/.claude/projects/<project-slug>.

.PARAMETER Force
  Overwrite files already extracted.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File system/scripts/extract-handbacks.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File system/scripts/extract-handbacks.ps1 -SessionId <uuid>
#>
param(
    [string]$SessionId,
    [switch]$All,
    [string]$ProjectDir,
    [string]$TranscriptRoot,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false

if (-not $ProjectDir) { $ProjectDir = $env:CLAUDE_PROJECT_DIR }
if (-not $ProjectDir) { $ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$ProjectDir = [System.IO.Path]::GetFullPath($ProjectDir).TrimEnd('\', '/')

if (-not $TranscriptRoot) {
    $slug = [regex]::Replace($ProjectDir, '[^A-Za-z0-9]', '-')
    $TranscriptRoot = Join-Path (Join-Path (Join-Path $env:USERPROFILE '.claude') 'projects') $slug
}
if (-not (Test-Path -LiteralPath $TranscriptRoot)) {
    Write-Host "No transcript folder for this project: $TranscriptRoot"
    exit 1
}

# --- secret redaction (shapes, not a guarantee) ---
$SecretPatterns = @(
    @{ kind = 'private-key';  rx = '-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?(?:-----END [A-Z ]*PRIVATE KEY-----|\z)' },
    @{ kind = 'bearer';       rx = '(?i)\bBearer\s+[A-Za-z0-9_\-\.=+/]{12,}' },
    @{ kind = 'url-credentials'; rx = '\b[a-z][a-z0-9+.\-]*://[^\s/:@]+:[^\s/@]+@' },
    @{ kind = 'anthropic-key'; rx = 'sk-ant-[A-Za-z0-9_\-]{16,}' },
    @{ kind = 'openai-key';   rx = '\bsk-(?:proj-)?[A-Za-z0-9_\-]{20,}' },
    @{ kind = 'stripe-key';   rx = '\b(?:sk|rk|pk)_(?:live|test)_[A-Za-z0-9]{16,}' },
    @{ kind = 'github-token'; rx = '\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})' },
    @{ kind = 'aws-key-id';   rx = '\b(?:AKIA|ASIA)[0-9A-Z]{16}\b' },
    @{ kind = 'slack-token';  rx = '\bxox[abposr]-[A-Za-z0-9\-]{10,}' },
    @{ kind = 'google-key';   rx = '\bAIza[0-9A-Za-z_\-]{35}\b' },
    @{ kind = 'jwt';          rx = '\beyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}' },
    @{ kind = 'assignment';   rx = '(?i)\b(password|passwd|pwd|secret|api[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret|account[_-]?key)(\s*[:=]\s*)["'']?[^\s"''`,;]{3,}' }
)
function Protect-Text([string]$text, [ref]$count) {
    if (-not $text) { return $text }
    foreach ($p in $SecretPatterns) {
        $kind = $p.kind
        $text = [regex]::Replace($text, $p.rx, {
            param($m)
            $count.Value++
            if ($kind -eq 'assignment') { return $m.Groups[1].Value + $m.Groups[2].Value + '[REDACTED:assignment]' }
            return "[REDACTED:$kind]"
        }.GetNewClosure())
    }
    return $text
}

function Get-TextFromContent($content) {
    if ($null -eq $content) { return $null }
    if ($content -is [string]) { return $content }
    $parts = @()
    foreach ($b in @($content)) { if ($b.type -eq 'text' -and $b.text) { $parts += [string]$b.text } }
    if ($parts.Count -eq 0) { return $null }
    return ($parts -join "`n`n")
}

# --- pick sessions ---
$sessions = @(Get-ChildItem -LiteralPath $TranscriptRoot -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'subagents') })
if ($SessionId) {
    $sessions = @($sessions | Where-Object { $_.Name -eq $SessionId })
    if ($sessions.Count -eq 0) { Write-Host "No session $SessionId with subagents under $TranscriptRoot"; exit 1 }
} elseif (-not $All) {
    # A session folder's own time does not move when a nested transcript is written: sort by the
    # newest transcript inside each one.
    $sessions = @($sessions | Sort-Object -Descending {
        $n = Get-ChildItem -LiteralPath (Join-Path $_.FullName 'subagents') -Filter 'agent-*.jsonl' -File |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($n) { $n.LastWriteTime } else { [datetime]::MinValue }
    } | Select-Object -First 1)
}
if ($sessions.Count -eq 0) { Write-Host "No session with subagents under $TranscriptRoot"; exit 0 }

$totals = [ordered]@{ written = 0; skipped_existing = 0; running = 0; unparsable_files = 0; no_output = 0; redactions = 0 }

foreach ($s in $sessions) {
    $outDir = Join-Path $ProjectDir (Join-Path 'outputs/fanouts/_handbacks' $s.Name)
    $files = @(Get-ChildItem -LiteralPath (Join-Path $s.FullName 'subagents') -Filter 'agent-*.jsonl' -File)
    Write-Host "Session $($s.Name): $($files.Count) subagent transcript(s) -> $outDir"

    foreach ($f in $files) {
        $agentId = $f.BaseName -replace '^agent-', ''
        $promptPath = Join-Path $outDir "$agentId`__prompt.md"
        $outputPath = Join-Path $outDir "$agentId`__output.md"
        if (-not $Force -and (Test-Path -LiteralPath $outputPath) -and (Test-Path -LiteralPath $promptPath)) {
            $totals.skipped_existing++; continue
        }

        $meta = $null
        $metaPath = Join-Path $f.DirectoryName ($f.BaseName + '.meta.json')
        if (Test-Path -LiteralPath $metaPath) {
            try { $meta = [System.IO.File]::ReadAllText($metaPath, $utf8) | ConvertFrom-Json } catch { $meta = $null }
        }
        if ($meta -and $meta.finished -ne $true) {
            $totals.running++
            Write-Host "  still running, skipped: $agentId"
            continue
        }

        $prompt = $null; $promptTs = $null
        $handbacks = New-Object System.Collections.Generic.List[object]   # each: id, text, ts
        $deniedIds = @{}
        $attempts = 0
        $lastText = $null; $lastTextTs = $null
        $badLines = 0
        try {
            $fs = New-Object System.IO.FileStream($f.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
            $reader = New-Object System.IO.StreamReader($fs, $utf8)
            try {
                while ($null -ne ($line = $reader.ReadLine())) {
                    # Cheap string pre-filters: only the records we need are parsed.
                    $wantPrompt = (-not $prompt) -and $line.Contains('"type":"user"')
                    $wantHandback = $line.Contains('"SubagentHandback"') -and $line.Contains('"tool_use"')
                    $wantText = $line.Contains('"type":"assistant"') -and $line.Contains('"type":"text"')
                    $wantError = ($attempts -gt 0) -and $line.Contains('"tool_result"') -and $line.Contains('"is_error":true')
                    if (-not ($wantPrompt -or $wantHandback -or $wantText -or $wantError)) { continue }
                    try { $o = $line | ConvertFrom-Json } catch { $badLines++; continue }
                    $c = $o.message.content
                    if ($wantPrompt -and $o.type -eq 'user' -and -not $o.isMeta) {
                        $t = Get-TextFromContent $c
                        if ($t) { $prompt = $t; $promptTs = $o.timestamp }
                    }
                    if ($o.type -eq 'assistant' -and $c -and -not ($c -is [string])) {
                        foreach ($b in @($c)) {
                            if ($b.type -eq 'tool_use' -and $b.name -eq 'SubagentHandback' -and $b.input.message) {
                                $handbacks.Add(@{ id = [string]$b.id; text = [string]$b.input.message; ts = $o.timestamp }); $attempts++
                            } elseif ($b.type -eq 'text' -and $b.text) {
                                $lastText = [string]$b.text; $lastTextTs = $o.timestamp
                            }
                        }
                    }
                    if ($wantError -and $o.type -eq 'user' -and $c -and -not ($c -is [string])) {
                        foreach ($b in @($c)) {
                            if ($b.type -eq 'tool_result' -and $b.is_error -eq $true -and $b.tool_use_id) { $deniedIds[[string]$b.tool_use_id] = $true }
                        }
                    }
                }
            } finally { $reader.Dispose(); $fs.Dispose() }
        } catch {
            $totals.unparsable_files++
            Write-Host "  skipped (cannot read): $($f.Name)"
            continue
        }

        $handback = $null; $handbackTs = $null; $hbState = $null
        for ($i = $handbacks.Count - 1; $i -ge 0; $i--) {
            if (-not $deniedIds.ContainsKey($handbacks[$i].id)) { $handback = $handbacks[$i].text; $handbackTs = $handbacks[$i].ts; $hbState = 'not denied'; break }
        }
        if (-not $handback -and $handbacks.Count -gt 0) {
            $last = $handbacks[$handbacks.Count - 1]
            $handback = $last.text; $handbackTs = $last.ts
            $hbState = 'DENIED (every call returned an error; this is the last attempt, not an accepted hand-back)'
        }

        if (-not $prompt -and -not $handback -and -not $lastText) {
            $totals.unparsable_files++
            Write-Host "  skipped (nothing parsable): $($f.Name)"
            continue
        }

        $source = "SubagentHandback, $hbState"
        $output = $handback; $outTs = $handbackTs
        if (-not $output) { $source = 'last assistant text (no SubagentHandback in transcript)'; $output = $lastText; $outTs = $lastTextTs }
        if (-not $output) { $totals.no_output++ }

        $red = 0
        $prompt = Protect-Text $prompt ([ref]$red)
        $output = Protect-Text $output ([ref]$red)
        # Header fields come from the sidecar: redact them too, and keep them from closing the comment.
        $desc = (Protect-Text ([string]$meta.description) ([ref]$red)) -replace '--', '- -'
        $atype = ([string]$meta.agentType) -replace '--', '- -'
        $totals.redactions += $red

        $hdr = @(
            "<!-- extracted by system/scripts/extract-handbacks.ps1 on $((Get-Date).ToString('s'))",
            "     session: $($s.Name)  agent: $agentId",
            "     agent_type: $atype  description: $desc",
            "     model: $($meta.model)  effort: $($meta.effort)",
            "     transcript: ~/.claude/projects/<project-slug>/$($s.Name)/subagents/$($f.Name)",
            "     redactions in this agent's files: $red (shape-based; review before sharing)  unparsable lines skipped: $badLines -->",
            ''
        ) -join "`n"

        if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
        $p = $hdr + "# Prompt ($agentId)`n`nfirst user record, $promptTs`n`n" + $(if ($prompt) { $prompt } else { '(no prompt text found)' }) + "`n"
        $o2 = $hdr + "# Hand-back ($agentId)`n`nsource: $source; SubagentHandback calls: $attempts; $outTs`n`n" + $(if ($output) { $output } else { '(no hand-back or assistant text found)' }) + "`n"
        [System.IO.File]::WriteAllText($promptPath, $p, $utf8)
        [System.IO.File]::WriteAllText($outputPath, $o2, $utf8)
        $totals.written++
        Write-Host ("  {0}: {1}, handback calls {2}, redactions {3}" -f $agentId, $(if ($handback) { 'handback' } elseif ($lastText) { 'last text' } else { 'no output' }), $attempts, $red)
    }
}

Write-Host ("Done: {0} agent(s) written, {1} already extracted (use -Force), {2} still running, {3} transcript(s) skipped, {4} without output, {5} redaction(s) (shape-based: review files before sharing)." -f $totals.written, $totals.skipped_existing, $totals.running, $totals.unparsable_files, $totals.no_output, $totals.redactions)
exit 0
