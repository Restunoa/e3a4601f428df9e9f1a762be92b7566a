# CONFIG
$zipUrl = "https://github.com/Restunoa/e3a4601f428df9e9f1a762be92b7566a/releases/download/master/unpack.zip"
$zipPath = "$env:TEMP\unpack.zip"
$robloxDir = "$env:LOCALAPPDATA\Roblox\Versions"

Write-Host "Downloading update package..."
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing

if (!(Test-Path $zipPath)) {
    Write-Host "Failed to download ZIP file."
    exit
}

Write-Host "Searching for Roblox installations..."
$targets = Get-ChildItem -Path $robloxDir -Directory |
    Where-Object { Test-Path "$($_.FullName)\RobloxPlayerBeta.exe" }

if ($targets.Count -eq 0) {
    Write-Host "No RobloxPlayerBeta.exe found."
    Remove-Item $zipPath
    exit
}

Write-Host "Found $($targets.Count) Roblox installation(s)."
Write-Host ""

# Extract ZIP contents to temp folder first
$tempExtract = "$env:TEMP\roblox_update_extract"
if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
Expand-Archive -Path $zipPath -DestinationPath $tempExtract -Force

# Get list of files to copy
$files = Get-ChildItem -Path $tempExtract -Recurse -File
$total = $files.Count
$index = 0

foreach ($target in $targets) {
    Write-Host "Updating: $($target.FullName)"

    $index = 0   # reset for each folder
    $total = $files.Count

    foreach ($file in $files) {
        $index++
        $relative = $file.FullName.Substring($tempExtract.Length)
        $dest = Join-Path $target.FullName $relative

        # Ensure destination directory exists
        $destDir = Split-Path $dest
        if (!(Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir | Out-Null
        }

        # Copy with overwrite
        Copy-Item -Path $file.FullName -Destination $dest -Force

        # REAL progress bar (never exceeds 100)
        $percent = [math]::Round(($index / $total) * 100, 2)
        if ($percent -gt 100) { $percent = 100 }

        Write-Progress -Activity "Updating $($target.Name)" `
                        -Status "$percent% complete" `
                        -PercentComplete $percent
    }

    Write-Progress -Activity "Updating $($target.Name)" -Completed
}


Write-Progress -Activity "Applying update..." -Completed

Write-Host ""
Write-Host "Update complete."

Remove-Item $zipPath
Remove-Item $tempExtract -Recurse -Force
