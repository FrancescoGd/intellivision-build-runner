
<#
.SYNOPSIS
    Compile, assemble, and launch an IntyBASIC project automatically.

.DESCRIPTION
    IBB - IntyBASIC Builder is a PowerShell script that automates the compilation (.bas -> .asm),
    assembly (.asm -> .bin), and execution of IntyBASIC source files using intybasic, as1600, and jzintv.
    It intelligently searches for required tools (PATH, environment variables, Get-Command) and displays clear, colored messages.

.PARAMETER source
    The name of the IntyBASIC source file (the .bas extension is not needed).
    Aliases: -f, -name, -project

.PARAMETER syntaxcheck
    If specified, only compile the .bas file and stop (syntax check only).
    Aliases: -sc, -checkonly, -syntax, -checksyntax

.EXAMPLE
    .\ibb.ps1 -source example
    Compiles example.bas, assembles it, and launches it with Jzintv.

.EXAMPLE
    .\ibb.ps1 -source example -syntaxcheck
    Only compiles example.bas to check for syntax errors

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
# Version   : 1.0.2
# Author    : fgd
# Copyright : 2025, present
# Info      : https://inty.furinkan.org/
#
#===============================================================================

# Check for [source] param and display help if not provided
param(
    [Alias("f", "name", "project")]
    [string]$source,
    [Alias("sc", "checkonly", "syntax", "checksyntax")]
    [switch]$syntaxcheck
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
    Write-Host ".\ibb.ps1 -source <filename> [-syntaxcheck]" -ForegroundColor Green
    Write-Host "Example:" -ForegroundColor Yellow
    Write-Host ".\ibb.ps1 -source example" -ForegroundColor Cyan
    Write-Host ".\ibb.ps1 -source example -syntaxcheck" -ForegroundColor Cyan
    Write-Host "`n-syntaxcheck : Only compile the .bas file and stop (syntax check only)." -ForegroundColor Yellow
    Write-Host "`nFor detailed help, run: Get-Help .\ibb.ps1 -Full" -ForegroundColor Yellow
    Write-Host "`n"
    exit
}

#===============================================================================
# Function: Test-Params
# Check if the params passed to the script are valid or are missing altogether
#===============================================================================
function Test-Params {
    # Check for explicit help request in arguments
    $helpSwitches = @("-h", "-help", "-?")
    if (-not $source -or $helpSwitches -contains $source.ToLower()) {
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

# Tool detection at startup
$intyBasicPath = Find-Tool -exeName "intybasic.exe" -folderHint "intybasic" -envVars @("INTV_BASIC_PATH", "INTV_SDK_PATH")
$as1600Path    = Find-Tool -exeName "as1600.exe" -folderHint "jzintv\bin" -envVars @("INTV_SDK_PATH")
$jzintvPath    = Find-Tool -exeName "jzintv.exe" -folderHint "jzintv\bin" -envVars @("JZINTV_HOME", "INTV_SDK_PATH")

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

# Normalize input: remove path and .bas extension if present
$source = [System.IO.Path]::GetFileNameWithoutExtension($source)

Write-Host "`nParameter received: $source`n" -ForegroundColor Green

# Compile .bas file into .asm using IntyBASIC
Write-Host "🏗️ Compiling $source.bas => $source.asm..." -ForegroundColor Yellow
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
Write-Host "🎁 Assembling $source.asm => $source.bin..." -ForegroundColor Cyan
& $as1600Path -o "$source.bin" "$source.asm"
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Assembly failed! The .asm file could not be assembled to .bin." -ForegroundColor Red
    exit
}

# Launch resulting .bin file using Jzintv
Write-Host "`n"
Write-Host "🚀 Executing $source.bin..." -ForegroundColor Magenta
& $jzintvPath ".\$source.bin"
