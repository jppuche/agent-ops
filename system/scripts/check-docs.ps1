<#
.SYNOPSIS
  Doc health check: keeps a project's governance docs fresh and consistent. Zero user overhead.

.DESCRIPTION
  Runs structural + reference + freshness checks over the project docs. Designed to be
  driven by Claude Code hooks (SessionStart = report, pre-commit = gate), NOT by the human:
  the report goes to the agent, which fixes what needs judgment. Read-only except -Mode fix,
  which only stamps last_verified from git (never touches prose).

  Agnostic by design: it checks the 6-doc governance layer any agent-ops instance ships
  (CLAUDE.md + the 5 living docs + the core system/ method). It does NOT know about any
  domain (no domain-specific gate assumptions); a domain kit can extend it if it needs more.

  Checks:
    1. Structure    - required governance files present.
    2. Broken refs  - markdown links to local files that don't exist (skips URLs/anchors/placeholders).
    3. Stale dates  - frontmatter last_verified older than the file's last git commit date.
    4. Freshness    - status.md / dev-changelog.md not updated despite commits today.
    5. Bootstrap    - leftover [PROJECT_NAME] placeholders in live docs.
  report mode also echoes the status.md "Active work" section (re-anchors the agent).

.PARAMETER Mode
  report (default) - print findings, exit 0.
  gate             - print findings, exit 2 if any ERROR (blocks a pre-commit hook).
  fix              - auto-stamp stale last_verified to the file's last commit date; print the rest.
                     The stamp asserts a verification nobody ran: use it only after re-reading the doc.

.PARAMETER RepoRoot
  Project root. Default: resolved from this script's location (system/scripts -> root).
#>
param(
    [ValidateSet('report', 'gate', 'fix')] [string]$Mode = 'report',
    [string]$RepoRoot
)

if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
# UTF-8 console output: without it, Windows PowerShell 5.1 mangles accented text echoed
# from the docs (mojibake in the SessionStart report).
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$ErrorActionPreference = 'Stop'

$errors = New-Object System.Collections.Generic.List[string]
$warns  = New-Object System.Collections.Generic.List[string]
$fixed  = New-Object System.Collections.Generic.List[string]

function Get-LastCommitDate([string]$fullPath) {
    try {
        $rel = $fullPath.Substring($RepoRoot.Length).TrimStart('\', '/')
        $d = git -C $RepoRoot log -1 --format=%cs -- "$rel" 2>$null
        if ($LASTEXITCODE -eq 0 -and $d) { return $d.Trim() }
    } catch {}
    return $null
}

$isGit = $false
try { git -C $RepoRoot rev-parse --is-inside-work-tree *> $null; $isGit = ($LASTEXITCODE -eq 0) } catch {}

# --- 1. Structure: required governance files ---
$required = @(
    'CLAUDE.md', 'docs/status.md', 'docs/scratchpad.md', 'docs/lessons-learned.md',
    'docs/decisions.md', 'docs/dev-changelog.md',
    'system/agent-orchestration.md', 'system/cross-validation-prompt.md'
)
foreach ($r in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $r))) { $errors.Add("missing required file: $r") }
}

# --- collect .md files (skip .git, node_modules, and heavy/vendored dirs) ---
$mdFiles = Get-ChildItem $RepoRoot -Recurse -Filter *.md -File |
    Where-Object { $_.FullName -notmatch '[\\/]\.claude[\\/]worktrees[\\/]|[\\/](\.git|node_modules|\.wrangler|dist|assets)[\\/]' }

# --- 2. Broken local references ---
foreach ($f in $mdFiles) {
    # Verbatim archives (agent prompts/outputs) are preserved unmodified by contract: a broken
    # link inside one cannot be fixed without breaking the archive, so it is not checked.
    if ($f.FullName -match '[\\/](outputs[\\/]fanouts|raw_agent_reports)[\\/]' -or $f.Name -match '__(prompt|output)\.md$') { continue }
    $text = Get-Content -LiteralPath $f.FullName -Encoding UTF8 -Raw
    foreach ($m in [regex]::Matches($text, '\]\(([^)]+)\)')) {
        $target = $m.Groups[1].Value.Trim()
        if ($target -match '^(https?:|mailto:|#)' -or $target -match '[<>*{}]' -or $target -eq '') { continue }
        $target = ($target -split '#')[0]
        if ($target -eq '') { continue }
        # only treat as a file ref if it has a path separator OR a known file extension
        # (skips schema placeholders like "url"/"title" inside example markdown)
        if ($target -notmatch '[\\/]' -and $target -notmatch '\.(md|ps1|sql|json|txt|png|jpg|csv|xlsx|yaml|yml|mjs|js|ts)$') { continue }
        if ($target -match '[\\/]') {
            # Markdown resolves a relative link against the LINKING FILE's directory; a
            # repo-root-relative path is accepted as a fallback (many docs write paths from the
            # root). Broken = fails from BOTH bases. A link that resolves OUTSIDE the repo
            # (../ to a sibling repo) is external - unverifiable here, so it is skipped; a ../
            # that stays inside the repo (docs/x.md -> ../system/y.md) IS checked.
            try {
                $fromFile = [System.IO.Path]::GetFullPath((Join-Path $f.DirectoryName $target))
            } catch { $errors.Add("broken ref in $($f.Name): $target"); continue }
            $rootFull = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/') + '\'
            if (-not $fromFile.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            $fromRoot = Join-Path $RepoRoot $target
            if (-not (Test-Path -LiteralPath $fromFile) -and -not (Test-Path -LiteralPath $fromRoot)) {
                $errors.Add("broken ref in $($f.Name): $target")
            }
        } else {
            $found = Get-ChildItem $RepoRoot -Recurse -Filter $target -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $found) { $errors.Add("broken ref in $($f.Name): $target") }
        }
    }
}

# --- 3. Stale last_verified vs git ---
if ($isGit) {
    foreach ($f in $mdFiles) {
        $head = Get-Content -LiteralPath $f.FullName -Encoding UTF8 -TotalCount 25
        $line = $head | Where-Object { $_ -match '^last_verified:\s*(\S+)' } | Select-Object -First 1
        if (-not $line) { continue }
        $declared = ($line -replace '^last_verified:\s*', '').Trim()
        if ($declared -notmatch '^\d{4}-\d{2}-\d{2}$') { continue }  # YYYY-MM-DD placeholder -> skip
        $committed = Get-LastCommitDate $f.FullName
        if ($committed -and ($declared -lt $committed)) {
            if ($Mode -eq 'fix') {
                $raw = Get-Content -LiteralPath $f.FullName -Encoding UTF8 -Raw
                $raw = [regex]::Replace($raw, '(?m)^last_verified:\s*\S+', "last_verified: $committed", 1)
                [System.IO.File]::WriteAllText($f.FullName, $raw)
                $fixed.Add("$($f.Name): last_verified $declared -> $committed")
            } else {
                $warns.Add("stale last_verified in $($f.Name): $declared < last commit $committed")
            }
        }
    }
}

# --- 4. status/changelog freshness vs today's commits ---
if ($isGit) {
    $today = (Get-Date).ToString('yyyy-MM-dd')
    $commitsToday = git -C $RepoRoot log --since=midnight --oneline 2>$null
    if ($commitsToday) {
        foreach ($sd in @('docs/status.md', 'docs/dev-changelog.md')) {
            $p = Join-Path $RepoRoot $sd
            if (Test-Path -LiteralPath $p) {
                $d = Get-LastCommitDate $p
                if ($d -ne $today) { $warns.Add("$sd not updated today, but there are commits today") }
            }
        }
    }
}

# --- 5. leftover template placeholders in live docs ---
foreach ($live in @('CLAUDE.md', 'docs/status.md', 'docs/decisions.md', 'docs/dev-changelog.md')) {
    $p = Join-Path $RepoRoot $live
    if (Test-Path -LiteralPath $p) {
        if ((Get-Content -LiteralPath $p -Encoding UTF8 -Raw) -match '\[PROJECT_NAME\]|\[PROJECT_TYPE\]') {
            $warns.Add("$live still has a [PROJECT_NAME] or [PROJECT_TYPE] placeholder (bootstrap incomplete)")
        }
    }
}

# --- output ---
function Write-Section($title, $items, $color) {
    if ($items.Count -eq 0) { return }
    Write-Host ""
    Write-Host "$title ($($items.Count)):" -ForegroundColor $color
    foreach ($i in $items) { Write-Host "  - $i" -ForegroundColor $color }
}

Write-Host "Doc health check ($Mode) - $RepoRoot"
Write-Section "FIXED"  $fixed  Green
Write-Section "ERRORS" $errors Red
Write-Section "WARN"   $warns  Yellow
if ($errors.Count -eq 0 -and $warns.Count -eq 0 -and $fixed.Count -eq 0) {
    Write-Host "  docs OK - no issues." -ForegroundColor Green
}

# --- Active-work echo (report mode: re-anchor the agent each session) ---
if ($Mode -eq 'report') {
    $st = Join-Path $RepoRoot 'docs/status.md'
    if (Test-Path -LiteralPath $st) {
        $inSection = $false
        $out = @()
        foreach ($ln in (Get-Content -LiteralPath $st -Encoding UTF8)) {
            if ($ln -match '^##\s+Active') { $inSection = $true; continue }
            elseif ($inSection -and $ln -match '^##\s') { break }
            elseif ($inSection) { $out += $ln }
        }
        $out = @($out | Where-Object { $_.Trim() -ne '' })
        if ($out.Count -gt 0) {
            Write-Host ""
            Write-Host "Active work (status.md - macro anchor):" -ForegroundColor Cyan
            $out | ForEach-Object { Write-Host "  $_" }
        }
    }
}

if ($Mode -eq 'gate' -and $errors.Count -gt 0) {
    Write-Host ""
    Write-Host "GATE: $($errors.Count) error(s) - resolve before committing." -ForegroundColor Red
    # exit 2 is the Claude Code PreToolUse signal that BLOCKS the tool call (stderr -> agent).
    [Console]::Error.WriteLine("Doc gate failed: $($errors -join '; ')")
    exit 2
}
exit 0
