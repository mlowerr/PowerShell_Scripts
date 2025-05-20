Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName PresentationFramework

function Create-Shortcut {
    param (
        [string]$targetFile,
        [string]$shortcutPath
    )
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $targetFile
    $shortcut.Save()
}

param(
    [string]$ReportFile = "DuplicateFilesReport.txt"
)

# Create the 0-Duplicate folder in the script's directory if it doesn't exist
$duplicateFolder = Join-Path -Path $PSScriptRoot -ChildPath "0-Duplicate"
if (-not (Test-Path -Path $duplicateFolder)) {
    New-Item -ItemType Directory -Path $duplicateFolder | Out-Null
}

# Load report and init state
$lines = Get-Content -Path $ReportFile
$currentFileGroup = ""
$currentFilePaths = @()

foreach ($line in $lines) {
    if ($line.Trim() -eq "" -or $line -match "^Duplicate Files Report") {
        continue
    }

    if ($line -notmatch "^\s") {
        # Process previous group
        if ($currentFilePaths.Count -gt 1 -and $currentFileGroup -like "*.mp4*") {
            # Determine target filename
            $fileName = ($currentFileGroup -split " \(Size:")[0].Trim()
            $targetFilePath = Join-Path -Path $duplicateFolder -ChildPath $fileName

            # If the file doesn't already exist in 0-Duplicate, copy one there
            if (-not (Test-Path -Path $targetFilePath)) {
                Copy-Item -Path $currentFilePaths[0] -Destination $targetFilePath -Force
            }

            # For all paths, delete the file and replace with shortcut
            foreach ($path in $currentFilePaths) {
                if ($path -ne $targetFilePath) {
                    try {
                        Remove-Item -LiteralPath $path -Force
                        $shortcutPath = [System.IO.Path]::ChangeExtension($path, "lnk")
                        Create-Shortcut -targetFile $targetFilePath -shortcutPath $shortcutPath
                    } catch {
                        Write-Warning "Failed to process path $_"
                    }
                }
            }
        }

        # Start new group
        $currentFileGroup = $line.Trim()
        $currentFilePaths = @()
    } else {
        $currentFilePaths += $line.Trim()
    }
}

# Final group processing
if ($currentFilePaths.Count -gt 1 -and $currentFileGroup -like "*.mp4*") {
    $fileName = ($currentFileGroup -split " \(Size:")[0].Trim()
    $targetFilePath = Join-Path -Path $duplicateFolder -ChildPath $fileName

    if (-not (Test-Path -Path $targetFilePath)) {
        Copy-Item -Path $currentFilePaths[0] -Destination $targetFilePath -Force
    }

    foreach ($path in $currentFilePaths) {
        if ($path -ne $targetFilePath) {
            try {
                Remove-Item -LiteralPath $path -Force
                $shortcutPath = [System.IO.Path]::ChangeExtension($path, "lnk")
                Create-Shortcut -targetFile $targetFilePath -shortcutPath $shortcutPath
            } catch {
                Write-Warning "Failed to process path $_"
            }
        }
    }
}

Write-Host "`n✅ All duplicate .mp4 files processed. Kept one copy in: $duplicateFolder"
