<#
.SYNOPSIS
  Captures a dispatched subagent prompt to the audit trail. Non-blocking (always exits 0).

.DESCRIPTION
  PreToolUse hook on the Agent/Task tool. Reads the tool-call JSON from stdin and appends
  the dispatched prompt (+ subagent type, description, and the call's model / effort /
  run_in_background, null when the call did not pass them) as one JSON line to
  outputs/fanouts/_dispatched-prompts.jsonl. This is the raw audit log behind the
  "prompt -> output -> integrated work" triad (see system/agent-orchestration.md sec 8):
  later you can evaluate which prompts produced which findings, and bounce them against
  the state of the art to improve the orchestration. Capture only - it NEVER blocks a dispatch.
#>
$ErrorActionPreference = 'SilentlyContinue'
try {
    $raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding $false))).ReadToEnd()  # hook input is UTF-8; [Console]::In would decode it with the OEM code page (850 here) and corrupt every accent
    if (-not $raw) { exit 0 }
    $j = $raw | ConvertFrom-Json
    if ($j.tool_name -ne 'Agent' -and $j.tool_name -ne 'Task') { exit 0 }
    $ti = $j.tool_input

    $root = $env:CLAUDE_PROJECT_DIR
    if (-not $root) { $root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
    $dir = Join-Path $root 'outputs/fanouts'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

    $entry = [ordered]@{
        ts            = (Get-Date).ToString('s')
        subagent_type = $ti.subagent_type
        description   = $ti.description
        prompt        = $ti.prompt
        model         = $ti.model              # per-call model override; null when the call did not pass one
        effort        = $ti.effort             # per-call effort override (Claude Code >= 2.1.292); null when absent
        run_in_background = $ti.run_in_background  # null when absent
    }
    $line = $entry | ConvertTo-Json -Compress -Depth 8
    [System.IO.File]::AppendAllText((Join-Path $dir '_dispatched-prompts.jsonl'), $line + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding $false))  # UTF-8 without BOM: in PS 5.1 `Add-Content -Encoding utf8` writes a BOM on file creation, and strict JSON parsers then reject record 1
} catch { }
exit 0
