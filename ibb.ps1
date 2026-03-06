<#
.SYNOPSIS
    Compile, assemble, and launch an IntyBASIC project automatically.

.DESCRIPTION
    IBB - IntyBASIC Builder is a PowerShell script that automates the compilation (.bas -> .asm),
    assembly (.asm -> .bin + .cfg by default, or .rom when -rom is specified), and execution of IntyBASIC source files
    using intybasic, as1600, and jzintv.
    It intelligently searches for required tools (PATH, environment variables, Get-Command) and displays clear, colored messages.
    Final output files (.bin/.cfg or .rom) can be moved to a custom output folder.

.PARAMETER source
    The name of the IntyBASIC source file (the .bas extension is not needed).
    Can be specified as the first positional argument or with the -source flag.
    Aliases: -f, -name, -project

.PARAMETER syntaxcheck
    If specified, only compile the .bas file and stop (syntax check only).
    Aliases: -sc, -checkonly, -syntax, -checksyntax

.PARAMETER outputfolder
    If specified, moves the final output files to the given folder (created if it doesn't exist).
    When using default BIN+CFG mode, moves .bin and (if present) .cfg.
    When using -rom mode, moves .rom.
    Jzintv will be launched from this folder.
    No aliases yet.

.PARAMETER rom
    If specified, produces a .rom output (Intellicart ROM format) instead of BIN+CFG.

.PARAMETER help
    Shows a concise usage summary and exits.
    Aliases: -h, -?

.EXAMPLE
    .\ibb.ps1 demo
    Compiles demo.bas, assembles it to demo.bin (+demo.cfg if generated), and launches it with Jzintv.

.EXAMPLE
    .\ibb.ps1 demo -rom
    Compiles demo.bas, assembles it to demo.rom, and launches it with Jzintv.

.EXAMPLE
    .\ibb.ps1 demo -syntaxcheck
    Only compiles demo.bas to check for syntax errors.

.EXAMPLE
    .\ibb.ps1 demo -outputfolder dist
    Builds and moves final assets to the 'dist' folder, then launches Jzintv from there.

.NOTES
    Author: fgd
    Copyright (c) 2025, present

.LINK
    https://inty.furinkan.org/
.LINK
    https://github.com/FrancescoGd/ibb/
#>

#===============================================================================
#
# IBB - IntyBASIC Builder
# Compile, Assemble and Launch an IntyBASIC source
#
# Version : 1.0.4
# Author : fgd
# Copyright : 2025, present
# Info : https://inty.furinkan.org/
#
#===============================================================================

# Check for [source] param and display help if not provided
param(
    [Parameter(Position = 0)]
    [Alias("f", "name", "project")]
    [string]$source,

    [Alias("sc", "checkonly", "syntax", "checksyntax")]
    [switch]$syntaxcheck,

    [string]$outputfolder,

    [switch]$rom,

    [Alias("h", "?")]
    [switch]$help
)

Clear-Host

#===============================================================================
# Function definitions
#===============================================================================

#===============================================================================
# Function: Show-Help
# Shows script usage if the user misses something or explicitly asks for it
#===============================================================================
function Show-Help {
    Write-Host "`n💡 IBB - IntyBASIC Builder" -ForegroundColor Blue
    Write-Host "Compile, assemble and launch an IntyBASIC source file." -ForegroundColor Blue
    Write-Host "`nUsage:" -ForegroundColor Yellow
    Write-Host ".\ibb.ps1 <filename> [-syntaxcheck] [-rom] [-outputfolder <folder>]" -ForegroundColor Green
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host ".\ibb.ps1 demo" -ForegroundColor Cyan
    Write-Host ".\ibb.ps1 demo -rom" -ForegroundColor Cyan
    Write-Host ".\ibb.ps1 demo -syntaxcheck" -ForegroundColor Cyan
    Write-Host ".\ibb.ps1 demo -outputfolder dist" -ForegroundColor Cyan
    Write-Host "`nFor detailed help, run: Get-Help .\ibb.ps1 -Full" -ForegroundColor Yellow
    Write-Host "`n"
    exit
}

#===============================================================================
# Function: Test-Params
# Check if the params passed to the script are valid or are missing altogether
#===============================================================================
function Test-Params {
    if ($help -or -not $source) {
        Show-Help
        exit
    }
}

#===============================================================================
# Function: Find-Tool
# Tries to locate a tool/executable by:
# 1. Searching with Get-Command
# 2. Searching for a folder in PATH (if specified)
# 3. Checking a specific environment variable (if provided)
# Returns the full path to the executable, or $null if not found.
#===============================================================================
function Find-Tool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$exeName,
        [string]$folderHint = "",
        [string[]]$envVars = @() # Accepts an array of env vars
    )

    # 1. Try to find the executable using Get-Command
    $cmd = Get-Command $exeName -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host "✅ Found $exeName using Get-Command! $($cmd.Source)" -ForegroundColor Green
        return $cmd.Source
    }

    # 2. Search for a folder in PATH (if folderHint is provided)
    if ($folderHint) {
        foreach ($dir in $env:PATH -split ';') {
            if ($dir -match $folderHint) {
                $fullPath = Join-Path $dir $exeName
                if (Test-Path $fullPath) {
                    Write-Host "✅ Found $exeName in PATH folder '$dir'!" -ForegroundColor Green
                    return $fullPath
                }
            }
        }
    }

    # 3. Check all provided environment variables (array)
    foreach ($envVar in $envVars) {
        $envPath = (Get-Item "Env:$envVar" -ErrorAction SilentlyContinue).Value
        if ($envPath) {
            $fullPath = Join-Path $envPath $exeName
            if (Test-Path $fullPath) {
                Write-Host "✅ Found $exeName using environment variable '$envVar'!" -ForegroundColor Green
                return $fullPath
            }
        }
    }

    # Not found
    Write-Host "❌ Could not find $exeName! Please check your installation." -ForegroundColor Red
    return $null
}

#===============================================================================
# Main script logic
#===============================================================================

Test-Params

# Normalize input: remove path and extensions if present
$source = [System.IO.Path]::GetFileNameWithoutExtension($source)

Write-Host "`nParameters received:" -ForegroundColor Green
Write-Host "- Source File: $source" -ForegroundColor Green
if ($syntaxcheck) { Write-Host "- Will execute syntax checking only" -ForegroundColor Green }
if ($rom) { Write-Host "- Output format: ROM" -ForegroundColor Green } else { Write-Host "- Output format: BIN+CFG" -ForegroundColor Green }
if ($outputfolder) { Write-Host "- Output folder: $outputfolder" -ForegroundColor Green }

# Check if the .bas file exists before proceeding
$basFile = ".\$source.bas"
if (-not (Test-Path $basFile)) {
    Write-Host "`n❌ Source file '$basFile' not found. Compilation cannot proceed." -ForegroundColor Red
    Write-Host "Suggestion: Please check the filename and ensure the .bas file exists in the current directory." -ForegroundColor Yellow
    exit
}

# Tool detection at startup
$intyBasicPath = Find-Tool -exeName "intybasic.exe" -folderHint "intybasic" -envVars @("INTV_BASIC_PATH", "INTV_SDK_PATH")
$as1600Path = Find-Tool -exeName "as1600.exe"    -folderHint "jzintv\bin" -envVars @("JZINTV_HOME", "INTV_SDK_PATH")
$jzintvPath = Find-Tool -exeName "jzintv.exe"    -folderHint "jzintv\bin" -envVars @("JZINTV_HOME", "INTV_SDK_PATH")

if (-not $intyBasicPath) {
    Write-Host "`n❌ intybasic.exe not found. Compilation cannot proceed." -ForegroundColor Red
    Write-Host "Suggestion: [placeholder] Please ensure IntyBASIC is installed and its folder is in your PATH or set the appropriate environment variable." -ForegroundColor Yellow
    exit
}
if (-not $as1600Path) {
    Write-Host "`n❌ as1600.exe not found. Assembly cannot proceed." -ForegroundColor Red
    Write-Host "Suggestion: [placeholder] Please ensure AS1600 is installed and its folder is in your PATH or set the appropriate environment variable." -ForegroundColor Yellow
    exit
}
if (-not $jzintvPath) {
    Write-Host "`n❌ jzintv.exe not found. Execution cannot proceed." -ForegroundColor Red
    Write-Host "Suggestion: [placeholder] Please ensure Jzintv is installed and its folder is in your PATH or set the appropriate environment variable." -ForegroundColor Yellow
    exit
}

# Compile .bas file into .asm using IntyBASIC
Write-Host "`n🏗️ Compiling $source.bas => $source.asm..." -ForegroundColor Yellow
& $intyBasicPath ".\$source.bas" ".\$source.asm"
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Compilation failed! The .bas file could not be compiled to .asm." -ForegroundColor Red
    exit
}

# Asked for syntax checking only, stop here
if ($syntaxcheck) {
    Write-Host "`n✅ Syntax check completed" -ForegroundColor Green
    exit
}

# Assemble .asm into either BIN+CFG (default) or ROM (when -rom is specified)
$outFile = if ($rom) { "$source.rom" } else { "$source.bin" }
Write-Host "`n🎁 Assembling $source.asm => $outFile..." -ForegroundColor Cyan
& $as1600Path -o $outFile "$source.asm"
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Assembly failed! The .asm file could not be assembled." -ForegroundColor Red
    exit
}

# Move final assets in destination dir if selected
if ($outputfolder) {
    Write-Host "`n"
    if (-not (Test-Path $outputfolder)) {
        # If destination dir doesn't exist, create it
        New-Item -ItemType Directory -Path $outputfolder -Force | Out-Null
    }

    $finalAssets = @()
    if ($rom) {
        $finalAssets = @("$source.rom")
    }
    else {
        # In BIN mode, as1600 typically produces .bin + .cfg
        $finalAssets = @("$source.bin", "$source.cfg")
    }

    foreach ($asset in $finalAssets) {
        if (Test-Path $asset) {
            Move-Item $asset (Join-Path $outputfolder $asset) -Force
            Write-Host "➡️ Moved $asset to $outputfolder" -ForegroundColor Green
        }
    }
}

# Path for launching Jzintv (follow selected output format and output folder)
$runFile = if ($rom) { "$source.rom" } else { "$source.bin" }
$runPath = if ($outputfolder) { Join-Path $outputfolder $runFile } else { ".\$runFile" }

Write-Host "`n🚀 Executing $runPath..." -ForegroundColor Magenta
& $jzintvPath $runPath
