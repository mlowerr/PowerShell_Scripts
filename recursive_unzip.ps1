# Define the root directory to start the search
$rootPath = "C:\Your\Target\Path"

# Recursively find all .zip files
$zipFiles = Get-ChildItem -Path $rootPath -Filter "*.zip" -Recurse

foreach ($file in $zipFiles) {
    # Define destination folder name (Zip file path minus the .zip extension)
    $destination = Join-Path -ChildPath $file.BaseName -Path $file.DirectoryName
    
    try {
        Write-Host "Extracting: $($file.FullName)" -ForegroundColor Cyan
        
        # Create directory if it doesn't exist and extract
        if (-not (Test-Path -Path $destination)) {
            New-Item -ItemType Directory -Path $destination | Out-Null
        }
        
        Expand-Archive -Path $file.FullName -DestinationPath $destination -Force
        
        # Verify extraction and delete original zip
        if (Test-Path -Path $destination) {
            Remove-Item -Path $file.FullName -Force
            Write-Host "Successfully deleted: $($file.Name)" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to process $($file.FullName): $($_.Exception.Message)"
    }
}
