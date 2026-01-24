<#
.SYNOPSIS
    Compile, assemble, and launch an IntyBASIC project automatically.

.DESCRIPTION
    IBB - IntyBASIC Builder is a PowerShell script that automates the compilation (.bas -> .asm),
    assembly (.asm -> .bin), optional ROM conversion (.bin -> .rom), and execution of IntyBASIC source files
    using intybasic, as1600, bin2rom (optional), and jzintv.
    It intelligently searches for required tools (PATH, environment variables, Get-Command) and displays clear, colored messages.
    Final output files (.bin, .rom, .cfg) can be moved to a custom output folder.

.PARAMETER source
    The name of the IntyBASIC source file (the .bas extension is not needed).
    Can be specified as the first positional argument or with the -source flag.
    Aliases: -f, -name, -project

.PARAMETER syntaxcheck
    If specified, only compile the .bas file and stop (syntax check only).
    Aliases: -sc, -checkonly, -syntax, -checksyntax

.PARAMETER outputfolder
    If specified, moves the final .bin, .rom, and .cfg files to the given folder (created if it doesn't exist).
    Jzintv will be launched from this folder.
    No aliases yet.

.PARAMETER help
    Shows a concise usage summary and exits.
    Aliases: -h, -?

.EXAMPLE
    .\ibb.ps1 demo
    Compiles demo.bas, assembles it, and launches it with Jzintv.

.EXAMPLE
    .\ibb.ps1 demo -syntaxcheck
    Only compiles demo.bas to check for syntax errors.

.EXAMPLE
    .\ibb.ps1 demo -outputfolder dist
    Compiles, assembles, and moves demo.bin, demo.rom, and demo.cfg to the 'dist' folder, then launches Jzintv from there.

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
# Version   : 1.0.4
# Author    : fgd
# Copyright : 2025, present
# Info      : https://inty.furinkan.org/
#
#===============================================================================

# Check for [source] param and display help if not provided
param(
    [Parameter(Position=0)]
    [Alias("f", "name", "project")]
    [string]$source,

    [Alias("sc", "checkonly", "syntax", "checksyntax")]
    [switch]$syntaxcheck,

    [string]$outputfolder,

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
    Write-Host ".\ibb.ps1 <filename> [-syntaxcheck] [-outputfolder <folder>]" -ForegroundColor Green
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host ".\ibb.ps1 demo" -ForegroundColor Cyan
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
if ($syntaxcheck) {
    Write-Host "- Will execute syntax checking only" -ForegroundColor Green
}

# Check if the .bas file exists before proceeding
$basFile = ".\$source.bas"
if (-not (Test-Path $basFile)) {
    Write-Host "`n❌ Source file '$basFile' not found. Compilation cannot proceed." -ForegroundColor Red
    Write-Host "Suggestion: Please check the filename and ensure the .bas file exists in the current directory." -ForegroundColor Yellow
    exit
}

# Tool detection at startup
$intyBasicPath = Find-Tool -exeName "intybasic.exe" -folderHint "intybasic" -envVars @("INTV_BASIC_PATH", "INTV_SDK_PATH")
$as1600Path    = Find-Tool -exeName "as1600.exe" -folderHint "jzintv\bin" -envVars @("JZINTV_HOME", "INTV_SDK_PATH")
$jzintvPath    = Find-Tool -exeName "jzintv.exe" -folderHint "jzintv\bin" -envVars @("JZINTV_HOME", "INTV_SDK_PATH")
$bin2RomPath   = Find-Tool -exeName "bin2rom.exe" -folderHint "jzintv\bin" -envVars @("JZINTV_HOME", "INTV_SDK_PATH")

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
if (-not $bin2RomPath) {
    # Note: i don't force-exit the script if everything except this was OK, this is considered an additional step.
    Write-Host "`n⚠️ bin2rom.exe not found. Execution will proceed without creating the additional ROM format (BIN will be created normally)." -ForegroundColor Yellow
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

# Assemble .asm file into .bin using AS1600
Write-Host "`n🎁 Assembling $source.asm => $source.bin..." -ForegroundColor Cyan
& $as1600Path -o "$source.bin" "$source.asm"
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Assembly failed! The .asm file could not be assembled to .bin." -ForegroundColor Red
    exit
}

# Create the additional .rom format using BIN2ROM
if ($bin2RomPath) {
    Write-Host "`n➡️ Creating also $source.bin => $source.rom..." -ForegroundColor Cyan
    & $bin2RomPath "$source.bin"
    if ($LASTEXITCODE -ne 0) {
        # Note: i don't force-exit the script if everything except this was OK, this is just an additional step.
        Write-Host "`n⚠️ Conversion failed! The .bin file could not be converted to .rom." -ForegroundColor Yellow
    }
}

# Move final assets in destination dir if selected
if ($outputfolder) {
    Write-Host "`n"
    if (-not (Test-Path $outputfolder)) {
        # If destination dir doesn't exist, create it
        New-Item -ItemType Directory -Path $outputfolder | Out-Null
    }
    $finalAssets = @("$source.bin", "$source.rom", "$source.cfg")
    foreach ($asset in $finalAssets) {
        if (Test-Path $asset) {
            Move-Item $asset (Join-Path $outputfolder $asset) -Force
            Write-Host "➡️ Moved $asset to $outputfolder" -ForegroundColor Green
        }
    }
}

# Path for launching Jzintv
if ($outputfolder) {
    $binPath = Join-Path $outputfolder "$source.bin"
} else {
    $binPath = ".\$source.bin"
}
# Launch resulting .bin file using Jzintv
Write-Host "`n🚀 Executing $binPath..." -ForegroundColor Magenta
& $jzintvPath $binPath
