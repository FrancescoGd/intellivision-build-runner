# IBB - IntyBASIC Builder

[![GitHub Repo](https://img.shields.io/badge/GitHub-IBB%20Repo-0078D4?logo=github&logoColor=white)](https://github.com/FrancescoGd/ibb)
[![Latest Release](https://img.shields.io/github/v/release/FrancescoGd/ibb?color=1DA1F2&label=Release&logo=starship&logoColor=white)](https://github.com/FrancescoGd/ibb/releases)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A _PowerShell_ script to compile, assemble, and launch _IntyBASIC_ projects automatically.

## Features

- Automatic detection of required tools (`intybasic`, `as1600`, `jzintv`)
- Syntax check-only mode (`-syntaxcheck`)
- Optional ROM output mode (`-rom`)
- Output folder support (`-outputfolder`) to move final assets
- Colored and clear status messages
- Usage help and parameter aliases

## Installation & Configuration

### 1. Download

- Download the latest version of `ibb.ps1` from the [GitHub repository](https://github.com/FrancescoGd/ibb/).
- Place the script in a folder of your choice.

### 2. Make it Globally Available (Optional)

- To run `ibb.ps1` from any location, add its folder to your `PATH` environment variable (either _user_ or _system_ vars).
- Example:
  - On Windows, open System Properties → Environment Variables → Edit `PATH` → Add the folder containing `ibb.ps1`.

### 3. Requirements

- **IntyBASIC**, **AS1600**, and **Jzintv** must be installed and available on your system.
- These tools do not have installers; simply download and extract them, then add their folders to your `PATH` or set the appropriate environment variables (`INTV_BASIC_PATH`, `INTV_SDK_PATH`, `JZINTV_HOME`).

### 4. First Run

- Open a PowerShell terminal.
- Navigate to the folder containing `ibb.ps1` (or any folder, if you added it to `PATH`).
- Run the script as shown in the usage examples:

```powershell
.\ibb.ps1 <filename>
```

- For syntax check only:

```powershell
.\ibb.ps1 <filename> -syntaxcheck
```

- To output a ROM instead of BIN+CFG:

```powershell
.\ibb.ps1 <filename> -rom
```

- To move final assets to a custom folder:

```powershell
.\ibb.ps1 <filename> -outputfolder dist
```

### 5. Troubleshooting

- If any required tool is missing, the script will display a clear error message and a suggestion for fixing the issue.
- Make sure all tool executables are accessible from your terminal (test with `intybasic`, `as1600`, `jzintv` commands).

**Tip:** You can use parameter aliases for convenience (see the section below).

## Usage

### Basic Usage

You can specify the source file either as the first positional argument or with the `-source` flag (and its aliases):

```powershell
.\ibb.ps1 demo
.\ibb.ps1 -source demo
.\ibb.ps1 demo -syntaxcheck
.\ibb.ps1 demo -rom
.\ibb.ps1 demo -outputfolder dist
.\ibb.ps1 demo -rom -outputfolder dist
```

- `-rom`: Produces a single `.rom` output using AS1600 (instead of the default `.bin` + `.cfg`).
- `-outputfolder <folder>`: Moves the final output files to the specified folder (created if it doesn't exist) and launches Jzintv from there.
  - In **BIN+CFG** mode (default): moves `.bin` and (if present) `.cfg`.
  - In **ROM** mode (`-rom`): moves `.rom`.
- All intermediate files remain in the working directory.

### Parameters and Aliases

- **-source**

  Aliases: `-f`, `-name`, `-project`

- **-syntaxcheck**

  Aliases: `-sc`, `-checkonly`, `-syntax`, `-checksyntax`

- **-outputfolder**

  No aliases yet

- **-rom**
  No aliases yet

- **-help**

  Aliases: `-?`, `-h`

💡 **Note** that you can omit the file extension in `<filename>` and it is also case-insensitive. Any path section will be purged too.

### Getting Help

- For a quick usage summary, you can run:

  ```powershell
  .\ibb.ps1 -?
  .\ibb.ps1 -h
  ```

  Any of these - including running the script with no parameters at all - will display a concise help message and exit.

- For full documentation, use the built-in PowerShell help system:

  ```powershell
  Get-Help .\ibb.ps1 -Full
  ```

  This will show all details, including parameters, examples, and notes.

## License

This project is released under the MIT License.

**Commercial use is permitted, but I kindly ask to contact the author if you plan to include this software in a commercial product or service.**

## Links

Website: [https://inty.furinkan.org/](https://inty.furinkan.org/)

Repository: [https://github.com/FrancescoGd/ibb/](https://github.com/FrancescoGd/ibb/)
