# PowerShell Scripts for Duplicate Media & Folder Reporting

This repository contains a set of PowerShell utilities for scanning large drives, detecting duplicate files, reporting folder sizes, and safely cleaning up redundant media. The scripts are designed to work together as a workflow: generate a duplicate report, choose a cleanup strategy (manual or automated), and optionally remove shortcut artifacts afterward.

## Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Scripts](#scripts)
  - [DirectoryList-RemovePrefix.ps1](#directorylist-removeprefixps1)
  - [DuplicateFiles.ps1](#duplicatefilesps1)
  - [FolderCountAndSize.ps1](#foldercountandsizeps1)
  - [Manage-Mp4Duplicates.ps1](#manage-mp4duplicatesps1)
  - [Process-DuplicateFileReport-GUI.ps1](#process-duplicatefilereport-guips1)
  - [mass delete command.txt](#mass-delete-commandtxt)
- [Recommended workflow](#recommended-workflow)
- [Notes & safety tips](#notes--safety-tips)

## Overview

These scripts focus on three common cleanup tasks:

1. **Inventorying duplicate files** by name and size.
2. **Summarizing folder size and file counts** to find storage hot spots.
3. **Cleaning up duplicates**, either manually (GUI selection) or automatically (MP4-only flow).

For a condensed overview table, see `SCRIPTS_OVERVIEW.md`.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+.
- Access permissions to the drive you plan to scan (defaults to `G:\`).
- For GUI-based selection, Windows Forms support is required.

> **Tip:** Many scripts default to `G:\`. Override with `-RootPath` or adjust the default if your storage lives elsewhere.

## Quick start

Run each script from a PowerShell prompt, optionally passing the parameters shown below:

```powershell
# 1) Generate a duplicate report
.\DuplicateFiles.ps1 -RootPath "G:\"

# 2a) Manual cleanup via GUI (generates a deletion script)
.\Process-DuplicateFileReport-GUI.ps1 -ReportFile "DuplicateFilesReport.txt"

# 2b) OR automatic cleanup for MP4 duplicates
.\Manage-Mp4Duplicates.ps1 -ReportFile "DuplicateFilesReport.txt"

# 3) Optional: remove shortcut files created by the MP4 manager
# (Use the snippet inside mass delete command.txt)
```

## Scripts

### DirectoryList-RemovePrefix.ps1

**Purpose:** Scan for directories that start with a known prefix and output the trimmed names.  
**Defaults:** `RootPath = "G:\"`, `OutputFile = "DirectoryListPrefixRemoved.txt"`.

**What it does:**
- Recursively walks the directory tree.
- Matches folder names that start with `Prefix -`.
- Writes the trimmed folder names to a log file.

**Example:**
```powershell
.\DirectoryList-RemovePrefix.ps1 -RootPath "G:\" -OutputFile "DirectoryListPrefixRemoved.txt"
```

### DuplicateFiles.ps1

**Purpose:** Find duplicate files by combining filename and size.  
**Defaults:** `RootPath = "G:\"`, `OutputFile = "DuplicateFilesReport.txt"`.

**What it does:**
- Recursively scans all files.
- Groups files by `Name + Length`.
- Writes a report with each duplicate set and its paths.

**Example:**
```powershell
.\DuplicateFiles.ps1 -RootPath "G:\" -OutputFile "DuplicateFilesReport.txt"
```

### FolderCountAndSize.ps1

**Purpose:** Generate a fixed-width report of file counts and total size per folder.  
**Defaults:** `RootPath = "G:\"`, `OutputFile = "file count and size.txt"`.

**What it does:**
- Enumerates all folders under the root.
- Counts files and sums file sizes per folder.
- Outputs a table aligned for easy copy/paste into spreadsheets.

**Example:**
```powershell
.\FolderCountAndSize.ps1 -RootPath "G:\" -OutputFile "file count and size.txt"
```

### Manage-Mp4Duplicates.ps1

**Purpose:** Automate cleanup of duplicate `.mp4` files from the duplicate report.  
**Default:** `ReportFile = "Duplicate Files Report.txt"`.

**What it does:**
- Reads the duplicate report.
- Processes only duplicate groups containing `.mp4`.
- Ensures one canonical copy is stored in a `0-Duplicate` folder next to the script.
- Deletes other `.mp4` duplicates and replaces them with `.lnk` shortcuts pointing to the kept copy.

**Example:**
```powershell
.\Manage-Mp4Duplicates.ps1 -ReportFile "DuplicateFilesReport.txt"
```

### Process-DuplicateFileReport-GUI.ps1

**Purpose:** Let you choose which duplicate to keep via a GUI.  
**Defaults:** `ReportFile = "DuplicateFilesReport.txt"`, `DeleteScriptFile = "delete-duplicates-script.txt"`.

**What it does:**
- Presents each duplicate group in a Windows Forms dialog.
- You select the file to keep.
- Creates a deletion script for the remaining paths (no files are deleted automatically).

**Example:**
```powershell
.\Process-DuplicateFileReport-GUI.ps1 -ReportFile "DuplicateFilesReport.txt"
```

### mass delete command.txt

**Purpose:** One-liner snippet to remove shortcut files created by the MP4 manager.

**What it does:**
- Searches for `.lnk` files under `G:\` and deletes them.
- Intended to be copied into a PowerShell console.

## Recommended workflow

1. **Run the duplicate report**
   ```powershell
   .\DuplicateFiles.ps1 -RootPath "G:\"
   ```
2. **Choose a cleanup path**
   - **Manual:** `Process-DuplicateFileReport-GUI.ps1` to generate a deletion script.
   - **Automated (MP4 only):** `Manage-Mp4Duplicates.ps1`.
3. **(Optional) Remove shortcuts** if you used the MP4 automation.

## Notes & safety tips

- Always review generated reports and deletion scripts before deleting files.
- The automated MP4 workflow **deletes files** and replaces them with shortcuts. Keep backups.
- The default root path is `G:\`. Adjust for your environment.
- Because grouping is based on *filename + size*, identical filenames of the same size are treated as duplicates even if their contents differ. If you need content-based verification, consider adding a hash step.
