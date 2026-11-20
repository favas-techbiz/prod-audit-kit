# Manual installer for Production Audit Kit (alternative to the plugin install).
# Usage: .\install\install.ps1                      -> installs for all projects (~\.claude)
#        .\install\install.ps1 -Project C:\path\repo -> installs into one project (<repo>\.claude)
param([string]$Project = "")
$ErrorActionPreference = "Stop"
$Here   = Split-Path -Parent $PSScriptRoot
$Src    = Join-Path $Here "plugins\prod-audit-kit"
$Base   = if ($Project) { $Project } else { $HOME }
$Target = Join-Path $Base ".claude"

New-Item -ItemType Directory -Force (Join-Path $Target "agents"), (Join-Path $Target "skills"), (Join-Path $Target "prod-audit\checklists") | Out-Null
Copy-Item (Join-Path $Src "agents\*.md") (Join-Path $Target "agents") -Force
foreach ($s in @("prod-audit", "prod-fix")) {
  $dest = Join-Path $Target "skills\$s"
  if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
  Copy-Item (Join-Path $Src "skills\$s") $dest -Recurse -Force
}
Write-Host "Installed Production Audit Kit into $Target"
Write-Host "Put your own checklists in $Target\prod-audit\checklists\ (kept across updates)."
Write-Host "Restart Claude Code, then type /prod-audit"
