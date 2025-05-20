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
    [string]$ReportFile = "Duplicate Files Report.txt"
)

# Resolve full path of 0-Duplicate folder in the script's directory
$duplicateFolder = Join-Path -Path $PSScriptRoot -ChildPath "0-Duplicate"
$duplicateFolder = [System.IO.Path]::GetFullPath($duplicateFolder)

# Ensure 0-Duplicate exists
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
            $fileName = ($currentFileGroup -split " \(Size:")[0].Trim()
            $targetFilePath = Join-Path -Path $duplicateFolder -ChildPath $fileName

            # If no copy in 0-Duplicate, move one there
            if (-not (Test-Path -Path $targetFilePath)) {
                $src = $currentFilePaths | Where-Object { -not ($_.StartsWith($duplicateFolder)) } | Select-Object -First 1
                if ($src) {
                    Move-Item -Path $src -Destination $targetFilePath -Force
                }
            }

            # Delete all .mp4 files NOT in 0-Duplicate and replace with shortcut
            foreach ($path in $currentFilePaths) {
                $fullPath = [System.IO.Path]::GetFullPath($path)
                if (-not $fullPath.StartsWith($duplicateFolder)) {
                    try {
                        Remove-Item -LiteralPath $fullPath -Force
                        $shortcutPath = [System.IO.Path]::ChangeExtension($fullPath, "lnk")
                        Create-Shortcut -targetFile $targetFilePath -shortcutPath $shortcutPath
                    } catch {
                        Write-Warning "Failed to process fullPath: $_"
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

# Final group
if ($currentFilePaths.Count -gt 1 -and $currentFileGroup -like "*.mp4*") {
    $fileName = ($currentFileGroup -split " \(Size:")[0].Trim()
    $targetFilePath = Join-Path -Path $duplicateFolder -ChildPath $fileName

    if (-not (Test-Path -Path $targetFilePath)) {
        $src = $currentFilePaths | Where-Object { -not ($_.StartsWith($duplicateFolder)) } | Select-Object -First 1
        if ($src) {
            Move-Item -Path $src -Destination $targetFilePath -Force
        }
    }

    foreach ($path in $currentFilePaths) {
        $fullPath = [System.IO.Path]::GetFullPath($path)
        if (-not $fullPath.StartsWith($duplicateFolder)) {
            try {
                Remove-Item -LiteralPath $fullPath -Force
                $shortcutPath = [System.IO.Path]::ChangeExtension($fullPath, "lnk")
                Create-Shortcut -targetFile $targetFilePath -shortcutPath $shortcutPath
            } catch {
                Write-Warning "Failed to process fullPath: $_"
            }
        }
    }
}

Write-Host "`n✅ All duplicate .mp4 files processed. One copy preserved in: $duplicateFolder"
