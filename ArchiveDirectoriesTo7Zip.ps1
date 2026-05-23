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

.PARAMETER CollisionPolicy
    Policy for handling pre-existing archive paths.

    Fail          = mark as failure and continue processing others.
    Skip          = skip the directory.
    TimestampedName = write to a timestamped .7z path.

.PARAMETER ThreadsPerArchive
    Number of 7-Zip threads per archive.

    If omitted, the script computes a safe default based on logical CPUs and
    -ConcurrentDirectories.

.PARAMETER SkipValidation
    Skip post-create `7z t` validation.

    Validation is enabled by default for data integrity.

.EXAMPLE
    .\ArchiveDirectoriesTo7Zip.ps1

.EXAMPLE
    .\ArchiveDirectoriesTo7Zip.ps1 -ConcurrentDirectories 2
#>

param (
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 64)]
    [int]$ConcurrentDirectories = 1,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Fail", "Skip", "TimestampedName")]
    [string]$CollisionPolicy = "Fail",

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1024)]
    [int]$ThreadsPerArchive,

    [Parameter(Mandatory = $false)]
    [switch]$SkipValidation
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

# Compute default per-archive threading safely when omitted.
if (-not $PSBoundParameters.ContainsKey("ThreadsPerArchive")) {
    $LogicalCpuCount = [Environment]::ProcessorCount
    $ThreadsPerArchive = [Math]::Max(1, [Math]::Floor($LogicalCpuCount / $ConcurrentDirectories))
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
Write-Host "Threads per archive: $ThreadsPerArchive"
Write-Host "Validation enabled: $(-not $SkipValidation.IsPresent)"
Write-Host "Collision policy: $CollisionPolicy"
Write-Host ""

# Track active 7-Zip processes.
$RunningProcesses = @{}

# Track outcomes.
$ResultCounts = [ordered]@{
    Success = 0
    Warning = 0
    Failed  = 0
    Skipped = 0
}

function Get-ExitClassification {
    param (
        [Parameter(Mandatory = $true)]
        [int]$ExitCode
    )

    switch ($ExitCode) {
        0 { return "Success" }
        1 { return "Warning" }
        default { return "Failed" }
    }
}

function Resolve-ArchivePath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$BaseArchivePath,

        [Parameter(Mandatory = $true)]
        [string]$Policy
    )

    if (-not (Test-Path -LiteralPath $BaseArchivePath)) {
        return [PSCustomObject]@{
            Action      = "Use"
            ArchivePath = $BaseArchivePath
            Message     = "Target available"
        }
    }

    switch ($Policy) {
        "Fail" {
            return [PSCustomObject]@{
                Action      = "Fail"
                ArchivePath = $BaseArchivePath
                Message     = "Archive exists"
            }
        }
        "Skip" {
            return [PSCustomObject]@{
                Action      = "Skip"
                ArchivePath = $BaseArchivePath
                Message     = "Archive exists"
            }
        }
        "TimestampedName" {
            $DirectoryPart = Split-Path -Path $BaseArchivePath -Parent
            $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($BaseArchivePath)
            $Extension = [System.IO.Path]::GetExtension($BaseArchivePath)
            $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $NewPath = Join-Path $DirectoryPart "$BaseName.$Timestamp$Extension"

            return [PSCustomObject]@{
                Action      = "Use"
                ArchivePath = $NewPath
                Message     = "Archive exists; using timestamped target"
            }
        }
    }
}

function Quarantine-Archive {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath
    )

    if (-not (Test-Path -LiteralPath $ArchivePath)) {
        return $null
    }

    $DirectoryPart = Split-Path -Path $ArchivePath -Parent
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($ArchivePath)
    $Extension = [System.IO.Path]::GetExtension($ArchivePath)
    $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $QuarantinePath = Join-Path $DirectoryPart "$BaseName.partial.$Timestamp$Extension"

    Move-Item -LiteralPath $ArchivePath -Destination $QuarantinePath -Force
    return $QuarantinePath
}

function Complete-ProcessRecord {
    param (
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Record,

        [Parameter(Mandatory = $true)]
        [switch]$SkipValidationSwitch,

        [Parameter(Mandatory = $true)]
        [hashtable]$ResultCounter,

        [Parameter(Mandatory = $true)]
        [string]$SevenZipPath
    )

    $classification = Get-ExitClassification -ExitCode $Record.Process.ExitCode

    if ($classification -eq "Success" -and -not $SkipValidationSwitch.IsPresent) {
        $ValidationProcess = Start-Process `
            -FilePath $SevenZipPath `
            -ArgumentList @("t", "-y", $Record.ArchivePath) `
            -NoNewWindow `
            -PassThru

        $ValidationProcess.WaitForExit()
        $validationClass = Get-ExitClassification -ExitCode $ValidationProcess.ExitCode

        if ($validationClass -ne "Success") {
            Write-Host ""
            Write-Host "ERROR: Archive validation failed; archive may be incomplete." -ForegroundColor Red
            Write-Host "Directory: $($Record.DirectoryPath)" -ForegroundColor Red
            Write-Host "Archive:   $($Record.ArchivePath)" -ForegroundColor Red
            Write-Host "Validate exit code: $($ValidationProcess.ExitCode)" -ForegroundColor Red
            $QuarantinePath = Quarantine-Archive -ArchivePath $Record.ArchivePath
            if ($QuarantinePath) {
                Write-Host "Quarantined: $QuarantinePath" -ForegroundColor Yellow
            }
            Write-Host ""

            if ($validationClass -eq "Warning") {
                $ResultCounter.Warning++
            }
            else {
                $ResultCounter.Failed++
            }
            return
        }
    }

    if ($classification -eq "Success") {
        Write-Host "Finished: $($Record.DirectoryPath)"
        $ResultCounter.Success++
        return
    }

    if ($classification -eq "Warning") {
        Write-Host ""
        Write-Host "WARNING: 7-Zip returned a warning; archive may be incomplete." -ForegroundColor Yellow
        Write-Host "Directory: $($Record.DirectoryPath)" -ForegroundColor Yellow
        Write-Host "Archive:   $($Record.ArchivePath)" -ForegroundColor Yellow
        Write-Host "Exit code: $($Record.Process.ExitCode)" -ForegroundColor Yellow
        $QuarantinePath = Quarantine-Archive -ArchivePath $Record.ArchivePath
        if ($QuarantinePath) {
            Write-Host "Quarantined: $QuarantinePath" -ForegroundColor Yellow
        }
        Write-Host ""

        $ResultCounter.Warning++
        return
    }

    Write-Host ""
    Write-Host "ERROR: 7-Zip failed; archive may be incomplete." -ForegroundColor Red
    Write-Host "Directory: $($Record.DirectoryPath)" -ForegroundColor Red
    Write-Host "Archive:   $($Record.ArchivePath)" -ForegroundColor Red
    Write-Host "Exit code: $($Record.Process.ExitCode)" -ForegroundColor Red
    $QuarantinePath = Quarantine-Archive -ArchivePath $Record.ArchivePath
    if ($QuarantinePath) {
        Write-Host "Quarantined: $QuarantinePath" -ForegroundColor Yellow
    }
    Write-Host ""

    $ResultCounter.Failed++
}

function Wait-ForAnyRunningProcess {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$RunningProcessMap
    )

    if ($RunningProcessMap.Count -eq 0) {
        return
    }

    # Prefer Wait-Process -Any when available (Windows PowerShell 7+).
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $ProcessIds = @($RunningProcessMap.Keys)
        Wait-Process -Id $ProcessIds -Any -ErrorAction SilentlyContinue
        return
    }

    # PowerShell 5.1-compatible fallback: briefly wait on each process handle.
    foreach ($ProcessId in @($RunningProcessMap.Keys)) {
        $Record = $RunningProcessMap[$ProcessId]
        if ($null -ne $Record -and -not $Record.Process.HasExited) {
            [void]$Record.Process.WaitForExit(250)
            if ($Record.Process.HasExited) {
                return
            }
        }
    }
}

function Complete-ExitedRunningProcesses {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$RunningProcessMap,

        [Parameter(Mandatory = $true)]
        [switch]$SkipValidationSwitch,

        [Parameter(Mandatory = $true)]
        [hashtable]$ResultCounter,

        [Parameter(Mandatory = $true)]
        [string]$SevenZipPath
    )

    foreach ($ProcessId in @($RunningProcessMap.Keys)) {
        $Record = $RunningProcessMap[$ProcessId]
        if ($Record.Process.HasExited) {
            Complete-ProcessRecord -Record $Record -SkipValidationSwitch:$SkipValidationSwitch -ResultCounter $ResultCounter -SevenZipPath $SevenZipPath
            $RunningProcessMap.Remove($ProcessId)
        }
    }
}

foreach ($Directory in $Directories) {

    # Archive file name is the directory name followed by .7z.
    $BaseArchivePath = Join-Path $RootPath "$($Directory.Name).7z"

    $ArchiveResolution = Resolve-ArchivePath -BaseArchivePath $BaseArchivePath -Policy $CollisionPolicy

    Write-Host "Destination decision: $($ArchiveResolution.Action) - $($ArchiveResolution.Message)"
    Write-Host "Directory: $($Directory.FullName)"
    Write-Host "Archive:   $($ArchiveResolution.ArchivePath)"

    if ($ArchiveResolution.Action -eq "Fail") {
        Write-Host "ERROR: Archive collision policy is Fail. Marking as failed." -ForegroundColor Red
        Write-Host ""
        $ResultCounts.Failed++
        continue
    }

    if ($ArchiveResolution.Action -eq "Skip") {
        Write-Host "SKIP: Archive collision policy is Skip." -ForegroundColor Yellow
        Write-Host ""
        $ResultCounts.Skipped++
        continue
    }

    $ArchivePath = $ArchiveResolution.ArchivePath

    Write-Host "Starting: $($Directory.FullName)"

    $SevenZipArgs = @(
        "a",
        "-t7z",
        "-mx=9",
        "-m0=LZMA2",
        "-md=256m",
        "-mfb=64",
        "-ms=16g",
        "-mmt=$ThreadsPerArchive",
        "-r",
        "-y",
        $ArchivePath,
        "."
    )

    $Process = Start-Process `
        -FilePath $SevenZipExe `
        -ArgumentList $SevenZipArgs `
        -WorkingDirectory $Directory.FullName `
        -NoNewWindow `
        -PassThru

    $RunningProcesses[$Process.Id] = [PSCustomObject]@{
        Process       = $Process
        DirectoryPath = $Directory.FullName
        ArchivePath   = $ArchivePath
    }

    while ($RunningProcesses.Count -ge $ConcurrentDirectories) {
        Wait-ForAnyRunningProcess -RunningProcessMap $RunningProcesses
        Complete-ExitedRunningProcesses -RunningProcessMap $RunningProcesses -SkipValidationSwitch:$SkipValidation -ResultCounter $ResultCounts -SevenZipPath $SevenZipExe
    }
}

while ($RunningProcesses.Count -gt 0) {
    Wait-ForAnyRunningProcess -RunningProcessMap $RunningProcesses
    Complete-ExitedRunningProcesses -RunningProcessMap $RunningProcesses -SkipValidationSwitch:$SkipValidation -ResultCounter $ResultCounts -SevenZipPath $SevenZipExe
}

Write-Host ""
Write-Host "All archive jobs completed."
Write-Host "Success: $($ResultCounts.Success)"
Write-Host "Warning: $($ResultCounts.Warning)"
Write-Host "Failed:  $($ResultCounts.Failed)"
Write-Host "Skipped: $($ResultCounts.Skipped)"

if ($ResultCounts.Warning -gt 0 -or $ResultCounts.Failed -gt 0) {
    exit 2
}

if ($ResultCounts.Skipped -gt 0) {
    exit 3
}

exit 0
