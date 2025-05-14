param(
    [string]$RootPath = "G:\",                    # Default root path to scan
    [string]$OutputFile = "DuplicateFilesReport.txt"  # Default output file
)

# Create a hashtable to group files by Name and Size
$filesGrouped = @{}

# Recursively scan all files
Get-ChildItem -Path $RootPath -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    $key = "$($_.Name)|$($_.Length)"  # Combine file name and size as key
    if (-not $filesGrouped.ContainsKey($key)) {
        $filesGrouped[$key] = @()
    }
    $filesGrouped[$key] += $_.FullName
}

# Filter for duplicates (more than 1 file with the same name and size)
$duplicates = $filesGrouped.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }

# Write results to file
"Duplicate Files Report - Generated on $(Get-Date)" | Out-File -FilePath $OutputFile
"" | Out-File -Append -FilePath $OutputFile

foreach ($entry in $duplicates) {
    $fileName, $fileSize = $entry.Key -split "\|"
    "$fileName (Size: $fileSize bytes)" | Out-File -Append -FilePath $OutputFile
    foreach ($path in $entry.Value) {
        "`t$path" | Out-File -Append -FilePath $OutputFile
    }
    "" | Out-File -Append -FilePath $OutputFile
}

Write-Host "Scan complete. Duplicate file report saved to: $OutputFile"
