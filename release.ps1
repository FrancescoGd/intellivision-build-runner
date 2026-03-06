#===============================================================================
#
# IBB Release Script
# Generate changelog, commit, tag, and push a new release for IBB
#
# Version   : 1.0.4
# Author    : fgd
# Copyright : 2025, present
# Info      : https://inty.furinkan.org/
#
#===============================================================================
param (
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$ScriptFile = "ibb.ps1",
    [string]$ProjectName = "IBB"
)
Write-Host "=== Starting release process for $ProjectName v$Version (PowerShell) ===" -ForegroundColor Cyan

# 0. Check for uncommitted changes
Write-Host "Checking for uncommitted changes..."
if (git status --porcelain) {
    Write-Host "Error: You have uncommitted changes. Please commit or stash them before releasing." -ForegroundColor Red
    exit 1
}

# 1. Check if git-cliff is installed
if (-not (Get-Command git-cliff -ErrorAction SilentlyContinue)) {
    Write-Host "Error: git-cliff is not installed. Please install it first." -ForegroundColor Red
    exit 1
}

# 2. Check if tag already exists
if (git tag --list "v$Version") {
    Write-Host "Error: Tag v$Version already exists. Aborting." -ForegroundColor Red
    exit 1
}


# 3. Update version in script file
Write-Host "Updating version in $ScriptFile..."
(Get-Content $ScriptFile) -replace '^(# Version\s+:).*$', "`$1 $Version" | Set-Content $ScriptFile

# Also update version in this release script
$releaseScript = $MyInvocation.MyCommand.Path
$tempRelease = "$releaseScript.tmp"
(Get-Content $releaseScript) -replace '^(# Version\s+:).*$', "`$1 $Version" | Set-Content $tempRelease
Move-Item -Force $tempRelease $releaseScript


# 4. Backup existing changelog
$outputFile = "CHANGELOG.md"
$backupFile = "changelog.md.bak"
if (Test-Path $outputFile) {
    Copy-Item $outputFile $backupFile -Force
    Write-Host "Backup of CHANGELOG.md created as $backupFile" -ForegroundColor Yellow
}

# 5. Generate changelog (all commits, newest first)
Write-Host "Generating changelog..."
git cliff --tag v$Version --output $outputFile
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $outputFile)) {
    Write-Host "Error: changelog generation failed." -ForegroundColor Red
    exit 1
}

# 5.1 Check if changelog has any commits
$changelogContent = Get-Content $outputFile | Where-Object { $_ -match '^- ' }
if (-not $changelogContent) {
    Write-Host "Warning: No commits found for changelog. Aborting release." -ForegroundColor Yellow
    exit 1
}

# 6. Commit release
Write-Host "Creating release commit..."
git add $ScriptFile $outputFile
git commit -m "chore(release): v$Version"

# 7. Tag and push
Write-Host "Tagging release..."
git tag -a "v$Version" -m "Release v$Version"
Write-Host "Pushing changes to remote..."
git push origin master
git push origin "v$Version"

Write-Host "✅ Release $ProjectName v$Version completed successfully!" -ForegroundColor Green
