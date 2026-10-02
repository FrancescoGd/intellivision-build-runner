BeforeAll {
    $ivbrPath = Join-Path $PSScriptRoot "..\ivbr.ps1"
    $ivbrAst = [System.Management.Automation.Language.Parser]::ParseFile(
        $ivbrPath,
        [ref]$null,
        [ref]$null
    )

    $functionsToLoad = @(
        "Find-Tool",
        "Get-SourceName",
        "Get-BuildOutputFile",
        "Get-FinalAssets",
        "Move-FinalAssets"
    )

    foreach ($functionName in $functionsToLoad) {
        $functionAst = $ivbrAst.Find({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq $functionName
            }, $true)

        . ([scriptblock]::Create($functionAst.Extent.Text))
    }
}

Describe "Comment-based help" {
    It "exposes all script parameters through Get-Help" {
        $help = Get-Help $ivbrPath -Full
        $parameterNames = @($help.parameters.parameter | ForEach-Object Name)

        $parameterNames | Should -Contain "source"
        $parameterNames | Should -Contain "syntaxcheck"
        $parameterNames | Should -Contain "outputfolder"
        $parameterNames | Should -Contain "rom"
        $parameterNames | Should -Contain "help"
    }
}

Describe "Find-Tool" {
    It "returns the command path when the executable is available through Get-Command" {
        Mock Get-Command { [pscustomobject]@{ Source = "C:\tools\intybasic.exe" } }

        $result = Find-Tool -exeName "intybasic.exe"

        $result.fullPath | Should -Be "C:\tools\intybasic.exe"
        $result.message | Should -Match "Get-Command"
    }

    It "returns no path when the executable cannot be found" {
        Mock Get-Command { $null }

        $result = Find-Tool -exeName "missing.exe"

        $result.fullPath | Should -BeNullOrEmpty
        $result.message | Should -Match "Could not find missing.exe"
    }

    It "finds an executable through an environment variable" {
        $toolFolder = Join-Path $TestDrive "tools"
        New-Item -ItemType Directory -Path $toolFolder | Out-Null
        New-Item -ItemType File -Path (Join-Path $toolFolder "as1600.exe") | Out-Null
        $env:TEST_TOOL_HOME = $toolFolder
        Mock Get-Command { $null }

        try {
            $result = Find-Tool -exeName "as1600.exe" -envVars "TEST_TOOL_HOME"
        }
        finally {
            Remove-Item Env:TEST_TOOL_HOME -ErrorAction SilentlyContinue
        }

        $result.fullPath | Should -Be (Join-Path $toolFolder "as1600.exe")
    }
}

Describe "Build output decisions" {
    It "normalizes a path and extension from the source name" {
        Get-SourceName -Source "samples\Demo.bas" | Should -Be "Demo"
    }

    It "selects BIN output by default" {
        Get-BuildOutputFile -Source "demo" | Should -Be "demo.bin"
        Get-FinalAssets -Source "demo" | Should -Be @("demo.bin", "demo.cfg")
    }

    It "selects ROM output when requested" {
        Get-BuildOutputFile -Source "demo" -Rom | Should -Be "demo.rom"
        Get-FinalAssets -Source "demo" -Rom | Should -Be @("demo.rom")
    }
}

Describe "Move-FinalAssets" {
    BeforeEach {
        $testDirectory = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $testDirectory | Out-Null
        Push-Location $testDirectory
    }

    AfterEach {
        Pop-Location
    }

    It "creates the destination and moves BIN and optional CFG assets" {
        New-Item -ItemType File -Name "demo.bin" | Out-Null
        New-Item -ItemType File -Name "demo.cfg" | Out-Null

        $messages = Move-FinalAssets -Source "demo" -OutputFolder "dist"

        Test-Path "dist\demo.bin" | Should -BeTrue
        Test-Path "dist\demo.cfg" | Should -BeTrue
        $messages | Should -Contain "[OK] Creating output directory: dist"
    }

    It "moves only the ROM asset in ROM mode" {
        New-Item -ItemType File -Name "demo.rom" | Out-Null
        New-Item -ItemType File -Name "demo.bin" | Out-Null

        Move-FinalAssets -Source "demo" -OutputFolder "dist" -Rom | Out-Null

        Test-Path "dist\demo.rom" | Should -BeTrue
        Test-Path "demo.bin" | Should -BeTrue
    }

    It "does not fail when the optional CFG asset is absent" {
        New-Item -ItemType File -Name "demo.bin" | Out-Null

        { Move-FinalAssets -Source "demo" -OutputFolder "dist" } | Should -Not -Throw
        Test-Path "dist\demo.bin" | Should -BeTrue
        Test-Path "dist\demo.cfg" | Should -BeFalse
    }
}
