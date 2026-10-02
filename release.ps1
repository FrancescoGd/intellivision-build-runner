#===============================================================================
#
# Intellivision Build Runner (IVBR) - Release Script
# Generate changelog, commit, tag, and push a new release
#
# Version   : 1.0.5
# Author    : fgd
# Copyright : 2025, present
# Info      : https://inty.furinkan.org/
#
#===============================================================================
param (
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,
    [string]$ScriptFile = "ivbr.ps1",
    [string]$ProjectName = "Intellivision Build Runner (IVBR)"
)
$ErrorActionPreference = "Stop"
$releaseScriptPath = [System.IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
$repositoryRoot = Split-Path -Parent $releaseScriptPath
$scriptPath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $ScriptFile))
$releaseScriptName = Split-Path -Leaf $releaseScriptPath
$outputFile = Join-Path $repositoryRoot "CHANGELOG.md"
$backupFile = Join-Path $repositoryRoot "changelog.md.bak"
$temporaryChangelog = Join-Path $repositoryRoot "CHANGELOG.md.tmp"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

Write-Host "=== Starting release process for $ProjectName v$Version (PowerShell) ===" -ForegroundColor Cyan

# 0. Check for uncommitted changes
Write-Host "Checking for uncommitted changes..."
Push-Location $repositoryRoot
$currentBranch = (git branch --show-current).Trim()
if (-not $currentBranch) {
    Pop-Location
    Write-Host "Error: could not determine the current Git branch." -ForegroundColor Red
    exit 1
}

if (git status --porcelain) {
    Pop-Location
    Write-Host "Error: You have uncommitted changes. Please commit or stash them before releasing." -ForegroundColor Red
    exit 1
}

# 1. Check if git-cliff is installed
if (-not (Get-Command git-cliff -ErrorAction SilentlyContinue)) {
    Pop-Location
    Write-Host "Error: git-cliff is not installed. Please install it first." -ForegroundColor Red
    exit 1
}

# 2. Check if tag already exists
if (git tag --list "v$Version") {
    Pop-Location
    Write-Host "Error: Tag v$Version already exists. Aborting." -ForegroundColor Red
    exit 1
}

# 3. Update versions in the scripts
Write-Host "Updating version in $ScriptFile..."
$scriptContent = [System.IO.File]::ReadAllText($scriptPath)
$scriptContent = $scriptContent -replace '(?m)^# Version\s+:.*$', "# Version   : $Version"
$scriptContent = $scriptContent -replace '(?m)^\$scriptVersion\s*=\s*"[^"]*"$', ('$scriptVersion = "' + $Version + '"')
[System.IO.File]::WriteAllText($scriptPath, $scriptContent, $utf8NoBom)

Write-Host "Updating version in $releaseScriptName..."
$releaseContent = [System.IO.File]::ReadAllText($releaseScriptPath)
$releaseContent = $releaseContent -replace '(?m)^# Version\s+:.*$', "# Version   : $Version"
[System.IO.File]::WriteAllText($releaseScriptPath, $releaseContent, $utf8NoBom)

# 4. Backup existing changelog
if (Test-Path $outputFile) {
    Copy-Item $outputFile $backupFile -Force
    Write-Host "Backup of CHANGELOG.md created as $backupFile" -ForegroundColor Yellow
}

# 5. Generate changelog (all commits, newest first)
Write-Host "Generating changelog..."
git cliff --tag v$Version --output $temporaryChangelog
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $temporaryChangelog)) {
    Remove-Item $temporaryChangelog -Force -ErrorAction SilentlyContinue
    Pop-Location
    Write-Host "Error: changelog generation failed." -ForegroundColor Red
    exit 1
}
Move-Item -Force $temporaryChangelog $outputFile

# 5.1 Check if changelog has any commits
$changelogContent = Get-Content $outputFile | Where-Object { $_ -match '^- ' }
if (-not $changelogContent) {
    Pop-Location
    Write-Host "Warning: No commits found for changelog. Aborting release." -ForegroundColor Yellow
    exit 1
}

# 6. Commit release
Write-Host "Creating release commit..."
git add -- $ScriptFile $releaseScriptName "CHANGELOG.md"
git commit -m "chore(release): v$Version"
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Host "Error: release commit failed." -ForegroundColor Red
    exit 1
}

# 7. Tag and push
Write-Host "Tagging release..."
git tag -a "v$Version" -m "Release v$Version"
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Host "Error: release tag creation failed." -ForegroundColor Red
    exit 1
}
Write-Host "Pushing changes to remote..."
git push origin $currentBranch
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Host "Error: pushing the release commit failed." -ForegroundColor Red
    exit 1
}
git push origin "v$Version"
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Host "Error: pushing the release tag failed." -ForegroundColor Red
    exit 1
}

Pop-Location

Write-Host "✅ Release $ProjectName v$Version completed successfully!" -ForegroundColor Green
