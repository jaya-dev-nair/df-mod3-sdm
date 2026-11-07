# secure-backup.ps1
# Automates backing up evidence and enforcing read-only integrity

$source = ".\Case-Source"
$backup = ".\Case-Backup"

# 1. Create source directory and dummy evidence file
New-Item -ItemType Directory -Path $source -Force | Out-Null
"Chain of Custody Log - $(Get-Date)" | Out-File "$source\custody.txt"

# 2. Copy contents to backup folder
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -Path "$source\*" -Destination $backup -Recurse -Force

# 3. Set all backed-up files to Read-Only
Get-ChildItem -Path $backup -File | ForEach-Object {
    Set-ItemProperty -Path $_.FullName -Name IsReadOnly -Value $true
}

Write-Output "Backup complete and locked as Read-Only."