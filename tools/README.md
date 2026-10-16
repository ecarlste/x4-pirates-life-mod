# Tools

Reusable scripts for working on the mod. Windows-side scripts are PowerShell (`.ps1`), since Egosoft's tools are Windows executables; they can also be run from WSL.

| Script | What it does |
| --- | --- |
| [`unpack-x4.ps1`](unpack-x4.ps1) | Unpacks the base game and every DLC into `E:\x4-dev\reference\x4-<version>\` (one folder per DLC, `_subst` for base-file replacements) |

## Running

From PowerShell, in the repo folder:

```powershell
.\tools\unpack-x4.ps1 -Version 9.00
```

If scripts are blocked, run it for the current session only:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\unpack-x4.ps1 -Version 9.00
```

From WSL:

```bash
powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w tools/unpack-x4.ps1)" -Version 9.00
```

Run `Get-Help .\tools\unpack-x4.ps1 -Full` for every parameter (`-X4Path`, `-OutRoot`, `-ToolPath`, `-Force`).

## Rules

- Unpacked game data is reference only. It lives outside the repo and is never committed.
- Prerequisite: "X Tools" installed from the Steam library (provides `XRCatTool.exe`).
