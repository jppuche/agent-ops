<#
.SYNOPSIS
  One-time setup for the agent-ops kit. Run from the cloned repo root.

.DESCRIPTION
  (1) Installs the kit's skills into ~/.claude/skills/ (user level), and
  (2) records this clone's absolute path in ~/.claude/agent-ops-home.txt so the
      init-project skill finds the master kit no matter where you cloned it.

  Re-run after a `git pull` that changes a skill, or after you move the clone.

  Note: skill updates hot-reload in an open Claude Code session. Only the FIRST install
  (when ~/.claude/skills/ did not exist before) needs a Claude Code restart so the new
  directory gets watched.
#>
$ErrorActionPreference = 'Stop'

$kitRoot   = $PSScriptRoot
$claudeDir = Join-Path $HOME '.claude'
$skillsDir = Join-Path $claudeDir 'skills'

Write-Host "agent-ops setup" -ForegroundColor Cyan
Write-Host "  kit:    $kitRoot"
Write-Host "  target: $skillsDir"

$freshInstall = -not (Test-Path $skillsDir)

# 1. install skills (user level)
New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
foreach ($s in (Get-ChildItem (Join-Path $kitRoot 'skills') -Directory)) {
    Copy-Item -Recurse -Force -Path $s.FullName -Destination $skillsDir
    Write-Host "  installed skill: $($s.Name)" -ForegroundColor Green
}

# 2. record the kit path so init-project finds the master, wherever it was cloned
$homeFile = Join-Path $claudeDir 'agent-ops-home.txt'
# UTF-8 WITHOUT a BOM: in Windows PowerShell 5.1 `Set-Content -Encoding utf8` prepends one,
# and a consumer that does not strip it reads an invisible character as part of the path.
[System.IO.File]::WriteAllText($homeFile, $kitRoot, (New-Object System.Text.UTF8Encoding $false))
Write-Host "  recorded kit path -> $homeFile" -ForegroundColor Green

Write-Host ""
if ($freshInstall) {
    Write-Host "First install: restart Claude Code so the new skills directory gets watched." -ForegroundColor Yellow
} else {
    Write-Host "Skills updated. They hot-reload in an open session - no restart needed." -ForegroundColor Yellow
}
