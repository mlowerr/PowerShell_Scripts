# PowerShell Scripts for Duplicate Media & Folder Reporting

This repo contains PowerShell utilities for:
- finding duplicate files,
- reporting folder size/file counts,
- and cleaning up duplicate media (manually or with MP4 automation).

For full per-script behavior and outputs, use `SCRIPTS_OVERVIEW.md` as the source of truth.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Read/write access to the target drive
- Windows Forms support for `Process-DuplicateFileReport-GUI.ps1`

> Most scripts default to `G:\`. Override with `-RootPath` where available.

## Recommended workflow

```powershell
# 1) Build a duplicate inventory report
.\DuplicateFiles.ps1 -RootPath "G:\" -OutputFile "DuplicateFilesReport.txt"

# 2a) Manual review path (creates deletion commands, does not auto-delete)
.\Process-DuplicateFileReport-GUI.ps1

# 2b) OR MP4 automation path (moves/deletes files)
# NOTE: this script defaults to "Duplicate Files Report.txt" (with spaces),
# so pass the report name explicitly if you used DuplicateFiles.ps1 defaults.
.\Manage-Mp4Duplicates.ps1 -ReportFile "DuplicateFilesReport.txt"

# 3) Optional shortcut cleanup
# See: mass delete command.txt
```

## Script list

- `DuplicateFiles.ps1`: scans recursively and groups duplicates by `Name + Length`.
- `Process-DuplicateFileReport-GUI.ps1`: GUI selection flow that writes `delete-duplicates-script.txt`.
- `Manage-Mp4Duplicates.ps1`: MP4-only automation that preserves one copy in `0-Duplicate` and replaces others with `.lnk` shortcuts.
- `FolderCountAndSize.ps1`: per-folder file count + size report.
- `DirectoryList-RemovePrefix.ps1`: finds directories starting with `Prefix -` and writes trimmed names.
- `mass delete command.txt`: one-liner helper for deleting shortcut files.

## Safety notes

- Review generated reports/scripts before deleting files.
- `Manage-Mp4Duplicates.ps1` performs file moves/deletes. Keep backups.
- Duplicate detection is name+size based (not hash/content based).
