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
    - output: the `message` input of the LAST SubagentHandback tool call (earlier ones were denied by
      a hook, e.g. check-closing-lines.ps1); when the transcript has none (older builds, or an agent
      that ended without one), the last assistant text, labelled as such.
  The sidecar agent-<id>.meta.json, when present, supplies agentType, description, model and effort.

  Writes, per agent: <agent-id>__prompt.md and <agent-id>__output.md (names check-docs.ps1 treats as
  verbatim archives). Existing files are skipped unless -Force. Prints only ids, counts and paths,
  never message text.

  Secrets: text that matches common credential shapes (API keys and tokens of several vendors, private
  key blocks, JWTs, `password=` / `api_key:` style assignments) is replaced by [REDACTED:<kind>] before
  it is written; the count is printed and recorded in the file header. Pattern matching misses what it
  does not know: review a file before you commit or share it. The output folder is gitignored by the
  kit's .gitignore; move what an audit needs into outputs/fanouts/<ticket>-<stage>/.

  Read-only on the transcripts. A line or file it cannot parse is skipped and counted. Windows
  PowerShell 5.1 compatible.

.PARAMETER SessionId
  Session to extract. Default: the most recently modified session folder that has subagents.

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
    @{ kind = 'private-key';  rx = '-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----' },
    @{ kind = 'anthropic-key'; rx = 'sk-ant-[A-Za-z0-9_\-]{16,}' },
    @{ kind = 'openai-key';   rx = '\bsk-(?:proj-)?[A-Za-z0-9_\-]{20,}' },
    @{ kind = 'github-token'; rx = '\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})' },
    @{ kind = 'aws-key-id';   rx = '\b(?:AKIA|ASIA)[0-9A-Z]{16}\b' },
    @{ kind = 'slack-token';  rx = '\bxox[abposr]-[A-Za-z0-9\-]{10,}' },
    @{ kind = 'google-key';   rx = '\bAIza[0-9A-Za-z_\-]{35}\b' },
    @{ kind = 'jwt';          rx = '\beyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}' },
    @{ kind = 'assignment';   rx = '(?i)\b(password|passwd|pwd|secret|api[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret)(\s*[:=]\s*)["'']?[^\s"''`,;]{6,}' }
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
    $sessions = @($sessions | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
}
if ($sessions.Count -eq 0) { Write-Host "No session with subagents under $TranscriptRoot"; exit 0 }

$totals = [ordered]@{ written = 0; skipped_existing = 0; unparsable_files = 0; no_output = 0; redactions = 0 }

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

        $prompt = $null; $promptTs = $null
        $handback = $null; $handbackTs = $null; $attempts = 0
        $lastText = $null; $lastTextTs = $null
        $badLines = 0
        try {
            $reader = New-Object System.IO.StreamReader($f.FullName, $utf8)
            try {
                while ($null -ne ($line = $reader.ReadLine())) {
                    # Cheap string pre-filters: only the records we need are parsed.
                    $wantPrompt = (-not $prompt) -and $line.Contains('"type":"user"')
                    $wantHandback = $line.Contains('"SubagentHandback"') -and $line.Contains('"tool_use"')
                    $wantText = $line.Contains('"type":"assistant"') -and $line.Contains('"type":"text"')
                    if (-not ($wantPrompt -or $wantHandback -or $wantText)) { continue }
                    try { $o = $line | ConvertFrom-Json } catch { $badLines++; continue }
                    $c = $o.message.content
                    if ($wantPrompt -and $o.type -eq 'user' -and -not $o.isMeta) {
                        $t = Get-TextFromContent $c
                        if ($t) { $prompt = $t; $promptTs = $o.timestamp }
                    }
                    if ($o.type -eq 'assistant' -and $c -and -not ($c -is [string])) {
                        foreach ($b in @($c)) {
                            if ($b.type -eq 'tool_use' -and $b.name -eq 'SubagentHandback' -and $b.input.message) {
                                $handback = [string]$b.input.message; $handbackTs = $o.timestamp; $attempts++
                            } elseif ($b.type -eq 'text' -and $b.text) {
                                $lastText = [string]$b.text; $lastTextTs = $o.timestamp
                            }
                        }
                    }
                }
            } finally { $reader.Dispose() }
        } catch {
            $totals.unparsable_files++
            Write-Host "  skipped (cannot read): $($f.Name)"
            continue
        }

        if (-not $prompt -and -not $handback -and -not $lastText) {
            $totals.unparsable_files++
            Write-Host "  skipped (nothing parsable): $($f.Name)"
            continue
        }

        $source = 'SubagentHandback'
        $output = $handback; $outTs = $handbackTs
        if (-not $output) { $source = 'last assistant text (no SubagentHandback in transcript)'; $output = $lastText; $outTs = $lastTextTs }
        if (-not $output) { $totals.no_output++ }

        $red = 0
        $prompt = Protect-Text $prompt ([ref]$red)
        $output = Protect-Text $output ([ref]$red)
        $totals.redactions += $red

        $hdr = @(
            "<!-- extracted by system/scripts/extract-handbacks.ps1 on $((Get-Date).ToString('s'))",
            "     session: $($s.Name)  agent: $agentId",
            "     agent_type: $($meta.agentType)  description: $($meta.description)",
            "     model: $($meta.model)  effort: $($meta.effort)",
            "     transcript: ~/.claude/projects/$(Split-Path $TranscriptRoot -Leaf)/$($s.Name)/subagents/$($f.Name)",
            "     redactions in this agent's files: $red  unparsable lines skipped: $badLines -->",
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

Write-Host ("Done: {0} agent(s) written, {1} already extracted (use -Force), {2} transcript(s) skipped, {3} without output, {4} redaction(s)." -f $totals.written, $totals.skipped_existing, $totals.unparsable_files, $totals.no_output, $totals.redactions)
exit 0
