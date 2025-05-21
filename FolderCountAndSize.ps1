param(
    [string]$RootPath = "G:\",                             # Root path to scan
    [string]$OutputFile = "file count and size.txt"        # Output report name
)

# Header
"Folder Report - Generated on $(Get-Date)" | Out-File -FilePath $OutputFile
"" | Out-File -Append -FilePath $OutputFile

# Table Header with aligned columns
$header = "{0,-60} {1,10} {2,15}" -f "Path", "File Count", "Size (GB)"
$divider = "-" * 90
$header | Out-File -Append -FilePath $OutputFile
$divider | Out-File -Append -FilePath $OutputFile

# Get all directories
Get-ChildItem -Path $RootPath -Recurse -Directory -Force -ErrorAction SilentlyContinue | Sort-Object FullName | ForEach-Object {
    $folderPath = $_.FullName
    try {
        $files = Get-ChildItem -Path $folderPath -File -Force -ErrorAction SilentlyContinue
        $fileCount = $files.Count
        $totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
        $sizeGB = if ($totalBytes) { [math]::Round($totalBytes / 1GB, 3) } else { 0 }

        $line = "{0,-60} {1,10} {2,15:N3}" -f $folderPath, $fileCount, $sizeGB
        $line | Out-File -Append -FilePath $OutputFile
    } catch {
        Write-Warning "Error processing $folderPath"
    }
}

Write-Host "Aligned report generated: $OutputFile"
