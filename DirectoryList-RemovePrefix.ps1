param(
    [string]$RootPath = "G:\",                                   # Root path to scan
    [string]$OutputFile = "DirectoryListPrefixRemoved.txt"             # Output file name
)

# Clear or create output file with header
"Folder List - Generated on $(Get-Date)" | Out-File -FilePath $OutputFile
"" | Out-File -Append -FilePath $OutputFile

# Define the match prefix
$prefix = "Prefix -"

# Get all directories that start with the prefix
Get-ChildItem -Path $RootPath -Recurse -Directory -Force -ErrorAction SilentlyContinue |
Where-Object { $_.Name -like "$prefix*" } |
Sort-Object FullName |
ForEach-Object {
    $folderName = $_.Name
    if ($folderName.Length -gt $prefix.Length) {
        $trimmedName = $folderName.Substring($prefix.Length)
        $trimmedName | Out-File -Append -FilePath $OutputFile
    }
}

Write-Host "Filtered folder names saved to: $OutputFile"
