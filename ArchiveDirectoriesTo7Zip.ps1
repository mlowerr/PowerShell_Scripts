<#
.SYNOPSIS
    Archives each direct child directory into its own .7z archive.

.DESCRIPTION
    This script scans the directory from which it is run, finds every direct
    child directory, and creates one .7z archive per directory.

    Each archive contains the recursive contents of that directory.

    The script processes directories concurrently based on the
    -ConcurrentDirectories parameter. The default is 1.

    This version avoids PowerShell Start-Job because Start-Job can be unstable
    when launching external console applications such as 7z.exe.

.PARAMETER ConcurrentDirectories
    Number of directories to archive at the same time.

    Defaults to 1.

.EXAMPLE
    .\ArchiveDirectoriesTo7Zip.ps1

.EXAMPLE
    .\ArchiveDirectoriesTo7Zip.ps1 -ConcurrentDirectories 2
#>

param (
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 64)]
    [int]$ConcurrentDirectories = 1
)

# Fail fast on script-level errors that are not explicitly handled.
$ErrorActionPreference = "Stop"

# Directory from which the script is run.
$RootPath = (Get-Location).Path

# Try to find 7z.exe from PATH first.
$SevenZipExe = (Get-Command "7z.exe" -ErrorAction SilentlyContinue).Source

# If 7z.exe is not in PATH, try the standard 7-Zip installation path.
if (-not $SevenZipExe) {
    $DefaultSevenZipPath = "C:\Program Files\7-Zip\7z.exe"

    if (Test-Path -LiteralPath $DefaultSevenZipPath) {
        $SevenZipExe = $DefaultSevenZipPath
    }
}

# Stop if 7-Zip cannot be found.
if (-not $SevenZipExe) {
    throw "7z.exe was not found. Install 7-Zip or add 7z.exe to PATH."
}

# Get only direct child directories of the current directory.
$Directories = Get-ChildItem -Path $RootPath -Directory

if (-not $Directories) {
    Write-Host "No direct child directories found in: $RootPath"
    exit 0
}

Write-Host "Root path: $RootPath"
Write-Host "7-Zip executable: $SevenZipExe"
Write-Host "Directories found: $($Directories.Count)"
Write-Host "Concurrent directories: $ConcurrentDirectories"
Write-Host ""

# Track active 7-Zip processes.
$RunningProcesses = @()

foreach ($Directory in $Directories) {

    # Archive file name is the directory name followed by .7z.
    $ArchivePath = Join-Path $RootPath "$($Directory.Name).7z"

    # Check whether the archive already exists before processing.
    #
    # This is an alert only:
    #   - The directory is not re-zipped.
    #   - The script continues processing other directories.
    if (Test-Path -LiteralPath $ArchivePath) {
        Write-Host ""
        Write-Host "ERROR: Archive already exists. Skipping directory." -ForegroundColor Red
        Write-Host "Directory: $($Directory.FullName)" -ForegroundColor Red
        Write-Host "Archive:   $ArchivePath" -ForegroundColor Red
        Write-Host ""
        continue
    }

    Write-Host "Starting: $($Directory.FullName)"
    Write-Host "Archive:  $ArchivePath"

    # 7-Zip arguments matching the screenshot settings.
    #
    # a
    #   Add files to archive.
    #
    # -t7z
    #   Archive format: 7z.
    #
    # -mx=9
    #   Compression level: 9 / Ultra.
    #
    # -m0=LZMA2
    #   Compression method: LZMA2.
    #
    # -md=256m
    #   Dictionary size: 256 MB.
    #
    # -mfb=64
    #   Word size / fast bytes: 64.
    #
    # -ms=16g
    #   Solid block size: 16 GB.
    #
    # -mmt=16
    #   Number of CPU threads: 16.
    #
    # -r
    #   Recurse through subdirectories.
    #
    # -y
    #   Assume Yes on all prompts.
    #
    # "."
    #   Archive the recursive contents of the source directory.
    #   The process working directory is set to the source directory,
    #   so this avoids storing full absolute paths in the archive.
    $SevenZipArgs = @(
        "a",
        "-t7z",
        "-mx=9",
        "-m0=LZMA2",
        "-md=256m",
        "-mfb=64",
        "-ms=16g",
        "-mmt=16",
        "-r",
        "-y",
        $ArchivePath,
        "."
    )

    # Start 7-Zip as a normal external process.
    #
    # Important:
    #   This does not use Start-Job.
    #   Avoiding Start-Job prevents PSSessionStateBroken errors caused by
    #   background PowerShell job transport issues.
    $Process = Start-Process `
        -FilePath $SevenZipExe `
        -ArgumentList $SevenZipArgs `
        -WorkingDirectory $Directory.FullName `
        -NoNewWindow `
        -PassThru

    # Track which directory/archive this process belongs to.
    $RunningProcesses += [PSCustomObject]@{
        Process       = $Process
        DirectoryPath = $Directory.FullName
        ArchivePath   = $ArchivePath
    }

    # Throttle active processes to the requested concurrency level.
    while (($RunningProcesses | Where-Object { -not $_.Process.HasExited }).Count -ge $ConcurrentDirectories) {

        Start-Sleep -Seconds 1

        # Check for completed processes.
        foreach ($Item in @($RunningProcesses)) {
            if ($Item.Process.HasExited) {

                if ($Item.Process.ExitCode -eq 0) {
                    Write-Host "Finished: $($Item.DirectoryPath)"
                }
                else {
                    Write-Host ""
                    Write-Host "ERROR: 7-Zip failed." -ForegroundColor Red
                    Write-Host "Directory: $($Item.DirectoryPath)" -ForegroundColor Red
                    Write-Host "Archive:   $($Item.ArchivePath)" -ForegroundColor Red
                    Write-Host "Exit code: $($Item.Process.ExitCode)" -ForegroundColor Red
                    Write-Host ""
                }

                # Remove completed process from tracking.
                $RunningProcesses = $RunningProcesses | Where-Object {
                    $_.Process.Id -ne $Item.Process.Id
                }
            }
        }
    }
}

# Wait for any remaining 7-Zip processes to finish.
while ($RunningProcesses.Count -gt 0) {

    Start-Sleep -Seconds 1

    foreach ($Item in @($RunningProcesses)) {
        if ($Item.Process.HasExited) {

            if ($Item.Process.ExitCode -eq 0) {
                Write-Host "Finished: $($Item.DirectoryPath)"
            }
            else {
                Write-Host ""
                Write-Host "ERROR: 7-Zip failed." -ForegroundColor Red
                Write-Host "Directory: $($Item.DirectoryPath)" -ForegroundColor Red
                Write-Host "Archive:   $($Item.ArchivePath)" -ForegroundColor Red
                Write-Host "Exit code: $($Item.Process.ExitCode)" -ForegroundColor Red
                Write-Host ""
            }

            # Remove completed process from tracking.
            $RunningProcesses = $RunningProcesses | Where-Object {
                $_.Process.Id -ne $Item.Process.Id
            }
        }
    }
}

Write-Host ""
Write-Host "All archive jobs completed."