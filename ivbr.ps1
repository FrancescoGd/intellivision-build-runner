<#
.SYNOPSIS
    Compile, assemble, and launch an IntyBASIC source file automatically.

.DESCRIPTION
    Intellivision Build Runner (IVBR) is a PowerShell script that automates the compilation (.bas -> .asm),
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

.PARAMETER rom
    If specified, produces a .rom output (Intellicart ROM format) instead of BIN+CFG.

.PARAMETER help
    Shows a concise usage summary and exits.
    Aliases: -h, -?

.EXAMPLE
    .\ivbr.ps1 demo
    Compiles demo.bas, assembles it to demo.bin (+demo.cfg if generated), and launches it with Jzintv.

.EXAMPLE
    .\ivbr.ps1 demo -rom
    Compiles demo.bas, assembles it to demo.rom, and launches it with Jzintv.

.EXAMPLE
    .\ivbr.ps1 demo -syntaxcheck
    Only compiles demo.bas to check for syntax errors.

.EXAMPLE
    .\ivbr.ps1 demo -outputfolder dist
    Builds and moves final assets to the 'dist' folder, then launches Jzintv from there.

.NOTES
    Author: fgd
    Copyright (c) 2025, present

.LINK
    https://inty.furinkan.org/
.LINK
    https://github.com/FrancescoGd/intellivision-build-runner/
#>

#===============================================================================
#
# Intellivision Build Runner (IVBR)
# Compile, Assemble and Launch an IntyBASIC source
#
# Version   : 1.0.5
# Author    : fgd
# Copyright : 2025, present
# Info      : https://inty.furinkan.org/
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

$scriptVersion = "1.0.5"

# Enable UTF-8 only on legacy Windows PowerShell
if ($PSVersionTable.PSEdition -eq 'Desktop' -and $IsWindows) {
    chcp 65001 > $null
    :OutputEncoding = [System.Text.UTF8Encoding]::new($false)
}

#===============================================================================
# Function definitions
#===============================================================================

#===============================================================================
# Function: Show-Help
# Shows script usage if the user misses something or explicitly asks for it
#===============================================================================
function Show-Help {
    Show-Panel `
        -Title "Quick Help" `
        -BorderColor Green `
        -Lines @(
        ""
        @{ Text = "Usage:" }
        @{ Text = ".\ivbr.ps1 <filename> [-syntaxcheck] [-rom] [-outputfolder <folder>]"; Color = "Cyan" }
        @{ Text = "Examples:" }
        @{ Text = ".\ivbr.ps1 demo"; Color = "Cyan" }
        @{ Text = ".\ivbr.ps1 demo -rom"; Color = "Cyan" }
        @{ Text = ".\ivbr.ps1 demo -syntaxcheck"; Color = "Cyan" }
        @{ Text = ".\ivbr.ps1 demo -outputfolder dist"; Color = "Cyan" }
        ""
        @{ Text = "For detailed help, run:"; Color = "Green"; NoNewLine = $true }
        @{ Text = "Get-Help .\ivbr.ps1 -Full"; Color = "White" }
        ""
    )

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

    $result = [PSCustomObject]@{
        message      = "[ERR] Could not find $exeName! Please check your installation."
        messageColor = [ConsoleColor]::Red
        fullPath     = $null
    }

    # 1. Try to find the executable using Get-Command
    $cmd = Get-Command $exeName -ErrorAction SilentlyContinue
    if ($cmd) {
        $result.message = "[OK] Found $exeName using Get-Command: $($cmd.Source)"
        $result.messageColor = [ConsoleColor]::Green
        $result.fullPath = $cmd.Source
    }

    # 2. Search for a folder in PATH (if folderHint is provided)
    if ($folderHint) {
        foreach ($dir in $env:PATH -split ';') {
            if ($dir -match $folderHint) {
                $fullPath = Join-Path $dir $exeName
                if (Test-Path $fullPath) {
                    $result.message = "[OK] Found $exeName in PATH folder: $dir"
                    $result.messageColor = [ConsoleColor]::Green
                    $result.fullPath = $fullPath
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
                $result.message = "[OK] Found $exeName using environment variable: $envVar"
                $result.messageColor = [ConsoleColor]::Green
                $result.fullPath = $fullPath
            }
        }
    }

    # Not found
    return $result
}

#===============================================================================
# Function: Get-SourceName
# Returns the base name of the source file without extension
#===============================================================================
function Get-SourceName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    return [System.IO.Path]::GetFileNameWithoutExtension($Source)
}

#===============================================================================
# Function: Get-BuildOutputFile
# Decide what kind of output file to produce based on the -rom switch
#===============================================================================
function Get-BuildOutputFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [switch]$Rom
    )

    if ($Rom) {
        return "$Source.rom"
    }

    return "$Source.bin"
}

#===============================================================================
# Function: Get-FinalAssets
# Returns the list of final assets to be moved based on the -rom switch
#===============================================================================
function Get-FinalAssets {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [switch]$Rom
    )

    if ($Rom) {
        return @("$Source.rom")
    }

    return @("$Source.bin", "$Source.cfg")
}

#===============================================================================
# Function: Move-FinalAssets
# Moves the final assets to the specified output folder, creating it if necessary
#===============================================================================
function Move-FinalAssets {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$OutputFolder,
        [switch]$Rom
    )

    $messages = @()
    if (-not (Test-Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
        $messages += "[OK] Creating output directory: $OutputFolder"
    }

    foreach ($asset in Get-FinalAssets -Source $Source -Rom:$Rom) {
        if (Test-Path $asset) {
            Move-Item $asset (Join-Path $OutputFolder $asset) -Force
            $messages += "[OK] Moved $asset to $OutputFolder"
        }
    }

    return $messages
}

#===============================================================================
# Function: Get-PlatformInfo
# Build and return platform information
#===============================================================================
function Get-PlatformInfo {
    # Retrieve OS info
    $os = Get-CimInstance Win32_OperatingSystem
    # Version (fe. 10.0.19045)
    $version = $os.Version

    # Architecture (maps to better names)
    $rawArch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    switch ($rawArch) {
        'X64' { $arch = 'AMD64' }
        'X86' { $arch = 'x86' }
        'Arm64' { $arch = 'ARM64' }
        default { $arch = $rawArch }
    }

    # Final string
    return "Windows [$version] / $arch"
}

#===============================================================================
# Function: Show-Banner
# Display IVBR coloured logo and platform info
#===============================================================================
function Show-Banner {
    $consoleWidth = [Console]::WindowWidth
    $systemString = Get-PlatformInfo

    # Main banner
    $spaces = " " * ([Math]::Max(0, [int](($consoleWidth - 33) / 2)) - 1)
    Write-Host "$spaces ██████╗██╗  ██╗██████╗ ██████╗" -ForegroundColor DarkBlue
    Write-Host "$spaces ╚═██╔═╝██║  ██║██╔══██╗██╔══██╗" -ForegroundColor DarkBlue
    Write-Host "$spaces   ██║  ██║  ██║██████╔╝██████╔╝" -ForegroundColor Blue
    Write-Host "$spaces   ██║  ╚██╗██╔╝██╔══██╗██╔══██╗" -ForegroundColor Cyan
    Write-Host "$spaces ██████╗ ╚═█╔═╝ ██████╔╝██║  ╚██╗" -ForegroundColor White
    Write-Host "$spaces ╚═════╝   ╚╝   ╚═════╝ ╚═╝   ╚═╝" -ForegroundColor White

    $spaces = " " * ([Math]::Max(0, [int](($consoleWidth - 83) / 2)) - 1)
    Write-Host "`n$spaces IntelliVision Build Runner - Compile, assemble and launch an IntyBASIC source file." -ForegroundColor Cyan
    Write-Host ""

    # System info panel
    Show-Panel `
        -Title "IVBR CLI Information" `
        -BorderColor Blue `
        -Lines @(
        ""
        @{ Text = "CLI Version:"; NoNewLine = $true }
        @{ Text = $scriptVersion; Color = "White" }
        @{ Text = "Platform:"; NoNewLine = $true }
        @{ Text = $systemString; Color = "White" }
        ""
    )
}

#===============================================================================
# Function: Show-Panel
# Display a nice colored panel with lines of text inside
#===============================================================================
function Show-Panel {
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [object[]]$Lines,

        [ConsoleColor]$BorderColor = "Blue",

        [int]$Width = 0
    )

    if ($Width -le 0) {
        $Width = $Host.UI.RawUI.WindowSize.Width
    }

    if ($Width -lt 20) {
        $Width = 20
    }

    $innerWidth = $Width - 2

    function ConvertTo-PanelSegment {
        param(
            [object]$Item
        )

        if ($Item -is [string]) {
            return [PSCustomObject]@{
                Text      = $Item
                Color     = $null
                NoNewLine = $false
            }
        }

        if ($Item -is [System.Collections.IDictionary]) {
            return [PSCustomObject]@{
                Text      = [string]$Item["Text"]
                Color     = $Item["Color"]
                NoNewLine = [bool]$Item["NoNewLine"]
            }
        }

        $propertyNames = $Item.PSObject.Properties.Name

        return [PSCustomObject]@{
            Text      = if ($propertyNames -contains "Text") { [string]$Item.Text } else { [string]$Item }
            Color     = if ($propertyNames -contains "Color") { $Item.Color } else { $null }
            NoNewLine = if ($propertyNames -contains "NoNewLine") { [bool]$Item.NoNewLine } else { $false }
        }
    }

    # Write a single panel row with text and left + right borders
    function Write-PanelRow {
        param(
            [object[]]$Segments
        )

        # 1chr left padding
        $maxContentWidth = $innerWidth - 1
        $usedWidth = 0

        Write-Host "│ " -NoNewLine -ForegroundColor $BorderColor

        foreach ($segment in $Segments) {
            $text = [string]$segment.Text

            if ([string]::IsNullOrEmpty($text)) {
                continue
            }

            $availableWidth = $maxContentWidth - $usedWidth

            if ($availableWidth -le 0) {
                break
            }

            if ($text.Length -gt $availableWidth) {
                $text = $text.Substring(0, $availableWidth)
            }

            $textColor = if ($null -ne $segment.Color) {
                [ConsoleColor]$segment.Color
            }
            else {
                $BorderColor
            }

            Write-Host $text -NoNewLine -ForegroundColor $textColor

            $usedWidth += $text.Length
        }

        $padding = $maxContentWidth - $usedWidth

        if ($padding -gt 0) {
            Write-Host (" " * $padding) -NoNewLine -ForegroundColor $BorderColor
        }

        Write-Host "│" -ForegroundColor $BorderColor
    }

    # Top border with centered title
    $header = " $Title "

    if ($header.Length -gt $innerWidth) {
        $header = $header.Substring(0, $innerWidth)
    }

    $remaining = $innerWidth - $header.Length
    $leftDash = [System.Math]::Floor($remaining / 2)
    $rightDash = $remaining - $leftDash

    Write-Host (
        "╭" +
        ("─" * $leftDash) +
        $header +
        ("─" * $rightDash) +
        "╮"
    ) -ForegroundColor $BorderColor

    $currentRow = [System.Collections.Generic.List[object]]::new()
    $insertBlankBeforeNext = $false

    foreach ($line in $Lines) {
        $segment = ConvertTo-PanelSegment -Item $line

        if ($insertBlankBeforeNext) {
            $currentRow.Add([PSCustomObject]@{
                    Text      = " "
                    Color     = $null
                    NoNewLine = $false
                })

            $insertBlankBeforeNext = $false
        }

        $currentRow.Add($segment)

        if ($segment.NoNewLine) {
            $insertBlankBeforeNext = $true
        }
        else {
            Write-PanelRow -Segments $currentRow.ToArray()
            $currentRow.Clear()
        }
    }

    if ($currentRow.Count -gt 0) {
        Write-PanelRow -Segments $currentRow.ToArray()
    }

    # Bottom border
    Write-Host (
        "╰" +
        ("─" * $innerWidth) +
        "╯"
    ) -ForegroundColor $BorderColor
}

function Show-Notice {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$MessageText,
        #[Parameter(Mandatory = $true)]
        #[string]$MessageText,
        [ValidateSet("Info", "Success", "Error", "Warning", IgnoreCase = $true)]
        [string]$MessageType = "Info",
        [bool]$ShowInPanel = $false,
        [bool]$NoPrint = $false
    )

    switch ($MessageType.ToLower()) {
        "info" {
            $messageColor = "Cyan"
            $messageIcon = "[INFO]"
            $messageTitle = "Information"
        }
        "success" {
            $messageColor = "Green"
            $messageIcon = "[OK]"
            $messageTitle = "Success!"
        }
        "warning" {
            $messageColor = "DarkYellow"
            $messageIcon = "[WARN]"
            $messageTitle = "Warning!"
        }
        "error" {
            $messageColor = "Red"
            $messageIcon = "[ERR]"
            $messageTitle = "Error!"
        }
    }

    if ($ShowInPanel) {
        Show-Panel `
            -Title $messageTitle `
            -BorderColor $messageColor `
            -Lines @(
            ""
            $MessageText
            ""
        )

    }
    else {
        if ($NoPrint) {
            return $messageIcon + $MessageText
        }
        else {
            Write-Host $messageIcon + $MessageText -ForegroundColor $messageColor
        }
    }
}

function Restore-Shell {
    param(
        [Parameter(Mandatory = $true)]
        [string]$backgroundColor,
        [Parameter(Mandatory = $true)]
        [string]$foregroundColor
    )


    $Host.UI.RawUI.BackgroundColor = $currentShellBackgroundColor
    $Host.UI.RawUI.ForegroundColor = $currentShellForegroundColor
}


#===============================================================================
# Main script logic
#===============================================================================

# Check shell's colors and set them for "branding"
$currentShellBackgroundColor = $Host.UI.RawUI.BackgroundColor
$currentShellForegroundColor = $Host.UI.RawUI.ForegroundColor
$Host.UI.RawUI.BackgroundColor = 'Black'
$Host.UI.RawUI.ForegroundColor = 'Cyan'

Clear-Host

# Show program logo and CLI info
Show-Banner

# Check CLI params and eventually display some quick help
Test-Params

$outputLines = @()

# Normalize input: remove path and extensions if present
$source = Get-SourceName -Source $source

$outputLines += "[X] Source File: $source"
if ($syntaxcheck) { $outputLines += "[X] Will execute syntax checking only" }
if ($rom) { $outputLines += "- Output format: ROM" } else { $outputLines += "[X] Output format: BIN+CFG" }
if ($outputfolder) { $outputLines += "[X] Output folder: $outputfolder" }

# Check if the .bas file exists before proceeding
$basFile = ".\$source.bas"
if (-not (Test-Path $basFile)) {
    Show-Notice `
        -MessageText @(
        "Source file '$basFile' not found. Compilation cannot proceed."
        "Suggestion: Please check the filename and ensure the .bas file exists in the current directory."
    ) `
        -MessageType Error `
        -ShowInPanel $true

    Restore-Shell -backgroundColor $currentShellBackgroundColor -foregroundColor $currentShellForegroundColor
    exit
}

$result = Find-Tool -exeName "intybasic.exe" -folderHint "intybasic" -envVars @("INTV_BASIC_PATH", "INTV_SDK_PATH")
if (-not $result.fullPath) {
    Show-Notice `
        -MessageText @(
        "Intybasic.exe not found. Compilation cannot proceed."
        "Suggestion: Please ensure IntyBASIC is installed and its folder is in your PATH,"
        "or you can also set INTV_BASIC_PATH and INTV_SDK_PATH"
    ) `
        -MessageType Error `
        -ShowInPanel $true

    Restore-Shell -backgroundColor $currentShellBackgroundColor -foregroundColor $currentShellForegroundColor
    exit
}
else {
    $outputLines += $result.message
    $intyBasicPath = $result.fullPath
}

# If syntax check only, no need to search for the other tools
if (-not $syntaxcheck) {
    $result = Find-Tool -exeName "as1600.exe" -folderHint "jzintv\bin" -envVars @("JZINTV_HOME", "INTV_SDK_PATH")
    if (-not $result.fullPath) {
        Show-Notice `
            -MessageText @(
            "As1600.exe not found. Assembly cannot proceed."
            "Suggestion: Please ensure AS1600 is installed and its folder is in your PATH,"
            "or you can also set JZINTV_HOME and INTV_SDK_PATH"
        ) `
            -MessageType Error `
            -ShowInPanel $true

        Restore-Shell -backgroundColor $currentShellBackgroundColor -foregroundColor $currentShellForegroundColor
        exit
    }
    else {
        $outputLines += $result.message
        $as1600Path = $result.fullPath
    }

    $result = Find-Tool -exeName "jzintv.exe" -folderHint "jzintv\bin" -envVars @("JZINTV_HOME", "INTV_SDK_PATH")
    if (-not $result.fullPath) {
        Show-Notice `
            -MessageText @(
            "Jzintv.exe not found. Execution cannot proceed."
            "Suggestion: Please ensure Jzintv is installed and its folder is in your PATH,"
            "or you can also set JZINTV_HOME and INTV_SDK_PATH"
            "Source will be compiled and assembled but the resulting ROM won't be executed."
        ) `
            -MessageType Warning `
            -ShowInPanel $true

        Restore-Shell -backgroundColor $currentShellBackgroundColor -foregroundColor $currentShellForegroundColor
        # exit
    }
    else {
        $outputLines += $result.message
        $jzintvPath = $result.fullPath
    }
}

Show-Panel `
    -Title "Environment and Parameters" `
    -BorderColor Green `
    -Lines $outputLines


# Compile .bas file into .asm using IntyBASIC
Show-Panel `
    -Title "IntyBASIC Step" `
    -BorderColor Yellow `
    -Lines @(
    ""
    "Compiling $source.bas => $source.asm..."
    ""
)

$Host.UI.RawUI.ForegroundColor = 'Yellow'

& $intyBasicPath ".\$source.bas" ".\$source.asm"
if ($LASTEXITCODE -ne 0) {
    Show-Notice `
        -MessageText @(
        "Compilation failed! The .bas file could not be compiled to .asm."
    ) `
        -MessageType Error `
        -ShowInPanel $true

    Restore-Shell -backgroundColor $currentShellBackgroundColor -foregroundColor $currentShellForegroundColor
    exit
}

# Asked for syntax checking only, stop here
if ($syntaxcheck) {
    Show-Notice `
        -MessageText @(
        "Syntax check completed, no errors detected."
    ) `
        -MessageType Success `
        -ShowInPanel $true

    Restore-Shell -backgroundColor $currentShellBackgroundColor -foregroundColor $currentShellForegroundColor
    exit
}

# Assemble .asm into either BIN+CFG (default) or ROM (when -rom is specified)
$outFile = Get-BuildOutputFile -Source $source -Rom:$rom

Show-Panel `
    -Title "AS1600 Step" `
    -BorderColor Cyan `
    -Lines @(
    ""
    "Assembling $source.asm => $outFile..."
    ""
)

$Host.UI.RawUI.ForegroundColor = 'Cyan'

& $as1600Path -o $outFile "$source.asm"
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[ERR] Assembly failed! The .asm file could not be assembled." -ForegroundColor Red
    exit
}

# Move final assets in destination dir if selected
if ($outputfolder) {
    $outputLines = Move-FinalAssets -Source $source -OutputFolder $outputfolder -Rom:$rom

    Show-Panel `
        -Title "Moving Resulting Assets" `
        -BorderColor Green `
        -Lines $outputLines

}

# If Jzintv hasn't been found, stop after ROM creation
if ($jzintvPath) {

    # Path for launching Jzintv (follow selected output format and output folder)
    $runFile = Get-BuildOutputFile -Source $source -Rom:$rom
    $runPath = if ($outputfolder) { Join-Path $outputfolder $runFile } else { ".\$runFile" }

    Write-Host ""

    Show-Panel `
        -Title "Execution Step" `
        -BorderColor Magenta `
        -Lines @(
        ""
        "Launching $runPath..."
        ""
    )

    $Host.UI.RawUI.ForegroundColor = 'Magenta'

    & $jzintvPath $runPath
}

# Restore user's values

Restore-Shell -backgroundColor $currentShellBackgroundColor -foregroundColor $currentShellForegroundColor
