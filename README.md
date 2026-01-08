# IBB - IntyBASIC Builder

[![GitHub Repo](https://img.shields.io/badge/GitHub-IBB%20Repo-0078D4?logo=github&logoColor=white)](https://github.com/FrancescoGd/ibb)
[![Latest Release](https://img.shields.io/github/v/release/FrancescoGd/ibb?color=1DA1F2&label=Release&logo=starship&logoColor=white)](https://github.com/FrancescoGd/ibb/releases)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A _PowerShell_ script to compile, assemble, and launch _IntyBASIC_ projects automatically.

## Features

- Automatic detection of required tools (`intybasic`, `as1600`, `jzintv`)
- Syntax check-only mode (`-syntaxcheck`)
- Colored and clear status messages
- Usage help and parameter aliases

## Parameter and Aliases

- **-source**
  Aliases: `-f`, `-name`, `-project`

- **-syntaxcheck**
  Aliases: `-sc`, `-checkonly`, `-syntax`, `-checksyntax`

## Usage

```powershell
.\ibb.ps1 -source <filename> [-syntaxcheck]
```

💡 **Note** that you can omit the file extension in ```<filename>``` and it is also case-insensitive. Any path section will be purged too.

### Examples

- Compile, assemble, and launch:

  ```powershell
  .\ibb.ps1 -source example
  ```

- Syntax check only:

  ```powershell
  .\ibb.ps1 -source example -syntaxcheck
  ```

## License

This project is released under the MIT License.

**Commercial use is permitted, but I kindly ask to contact the author if you plan to include this software in a commercial product or service.**

## Author

Nibunnoichi aka Peter Pepper
Website: [https://inty.furinkan.org/](https://inty.furinkan.org/)
Repository: [https://github.com/FrancescoGd/ibb/](https://github.com/FrancescoGd/ibb/)
