# Module 3: Secure Data Management (SDM)

## Secure Data Management (SDM)

### Files, Folders, and Event Logs
To gather system usage data and preserve forensic artifacts, I collected recent Windows System event logs, filtered them for specific error entries, and exported the results into structured formats:

```powershell
# Gather recent System events and save to a text file
Get-WinEvent -LogName System -MaxEvents 50 > system-logs.txt

# Search for "Error" entries and export to CSV
Get-Content system-logs.txt | Select-String "Error" | Export-Csv -Path filtered-errors.csv -NoTypeInformation
```
* **Forensic Value:** Redirecting logs to `.txt` and `.csv` creates an immutable, searchable snapshot of system activity for analysis without altering live system logs.

### Encryption & Access Control Lists (ACLs)
To protect sensitive evidence at rest, I created an evidence directory (`3-Evidence`), created an encrypted destination (`3-Evidence-Encrypted`) using Windows Encrypting File System (EFS), and restricted its Access Control List (ACL):

```powershell
# Create evidence directory and sample file
New-Item -ItemType Directory -Name "3-Evidence"
"Confidential Case Data - Do Not Alter" > "3-Evidence\case-notes.txt"

# Create and encrypt destination directory
New-Item -ItemType Directory -Name "3-Evidence-Encrypted"
cipher /e "3-Evidence-Encrypted"
Copy-Item "3-Evidence\*" -Destination "3-Evidence-Encrypted\"

# Capture baseline ACL
Get-Acl "3-Evidence" | Format-List > 3-Evidence-ACL.txt

# Disable inheritance and restrict access to Administrators with inheritance flags
$acl = Get-Acl "3-Evidence-Encrypted"
$acl.SetAccessRuleProtection($true, $false)$adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "Administrators",
    "FullControl",
    "ContainerInherit,ObjectInherit",
    "None",
    "Allow"
)
$acl.SetAccessRule($adminRule)
Set-Acl "3-Evidence-Encrypted" $acl

# Capture updated ACL for comparison
Get-Acl "3-Evidence-Encrypted" | Format-List > 3-Evidence-Encrypted-ACL.txt
```
* **Why This Matters:** Encryption ensures **confidentiality** (preventing unauthorized users from reading data at rest), while restricting ACLs ensures only authorized investigators (`Administrators`) can access the directory. Including `ContainerInherit,ObjectInherit` ensures files inside the folder inherit the administrator permissions properly.

---

## Managing Permissions

To protect forensic evidence copies from accidental modification or overwriting, I applied the **Read-Only** attribute to the copied evidence file:

```powershell
# Set evidence file to Read-Only
Set-ItemProperty -Path "3-Evidence-Encrypted\case-notes.txt" -Name IsReadOnly -Value $true

# Verify attribute change (Mode displays '-ar--')
Get-ChildItem "3-Evidence-Encrypted"
```
* **Forensic Value:** Enforcing Read-Only attributes supports data **integrity** by preventing accidental edits to working copies of digital evidence.

---

## PowerShell Scripting

I created `secure-backup.ps1` to automate creating a chain-of-custody source file, copying it to a backup folder, and locking all backed-up files as Read-Only:

```powershell
$source = ".\Case-Source"
$backup = ".\Case-Backup"

# 1. Create source directory and dummy evidence file
New-Item -ItemType Directory -Path $source -Force | Out-Null
"Chain of Custody Log - $(Get-Date)" \vert{} Out-File "$source\custody.txt"

# 2. Copy contents to backup folder
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -Path "$source\*" -Destination $backup -Recurse -Force

# 3. Set all backed-up files to Read-Only
Get-ChildItem -Path $backup -File | ForEach-Object {
    Set-ItemProperty -Path $_.FullName -Name IsReadOnly -Value$true
}

Write-Output "Backup complete and locked as Read-Only."
```
* **Why This Matters:** Automating backups and read-only enforcement reduces human error, ensures repeatable forensic workflows, and preserves evidence integrity immediately upon collection.

---

## Bonus: Additional Forensic & Integrity Commands

To further strengthen evidence verification and system state collection beyond the base requirements, I ran three additional PowerShell and Windows CLI commands:

```powershell
# 1. Verify file integrity using SHA256 hashes before and after backup
Get-FileHash ".\Case-Source\custody.txt", ".\Case-Backup\custody.txt" -Algorithm SHA256 | Export-Csv -Path "hash-verification.csv" -NoTypeInformation

# 2. Verify EFS encryption status and certificate thumbprints on the encrypted evidence file
cipher /c "3-Evidence-Encrypted\case-notes.txt" > encryption-status.txt

# 3. Capture active TCP network connections for volatile system state documentation
Get-NetTCPConnection | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State | Export-Csv -Path "network-connections.csv" -NoTypeInformation
```

### Forensic Value of Additional Commands
* **Cryptographic Hashing (`Get-FileHash`):** Generates SHA256 checksums for both the original and backed-up files in `hash-verification.csv`, proving mathematically that no bits changed during transfer and upholding chain-of-custody integrity.
* **Encryption Verification (`cipher /c`):** Audits the Windows Encrypting File System (EFS) metadata on `case-notes.txt` and outputs the authorized user certificate details to `encryption-status.txt`, verifying confidentiality at rest.
* **Volatile Network Artifact Collection (`Get-NetTCPConnection`):** Captures active local/remote IP addresses, ports, and connection states into `network-connections.csv`, preserving volatile network evidence before it is lost.