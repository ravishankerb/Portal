$MigrationPath = "C:\ProgramData\AADMigration"
. $MigrationPath\Scripts\LogMigrationStatus.ps1

# Define the drive letter and event log parameters
$driveLetter = "C:"
$eventLogName = "Application"
$eventSource = "AAD_Migration_Script2"
$eventID_DecryptionComplete = 1350
$eventID_DecryptionInProgress = 1351
$eventID_NotEnabled = 1352
$eventID_DriveLocked = 1353

# Function to write event to Event Viewer
function Write-Event {
    param (
        [string]$message,
        [int]$eventID
    )
    if (-not (Get-EventLog -LogName $eventLogName -Source $eventSource -ErrorAction SilentlyContinue)) {
        New-EventLog -LogName $eventLogName -Source $eventSource
    }
    Write-EventLog -LogName $eventLogName -Source $eventSource -EventID $eventID -EntryType Information -Message $message
    Insert-MigrationStatus "During Migration" $message "CheckBitLockerDecryptionStatus.ps1" "Info"
}

# Check if BitLocker is enabled on the drive
$bitlockerVolumes = Get-BitLockerVolume

# Variable to track if all volumes are decrypted
$allDecrypted = $true

# Loop through each BitLocker volume and check if it is decrypted
foreach ($volume in $bitlockerVolumes) {

    if ($volume.ProtectionStatus -eq "Off") {
        $message = "BitLocker is not enabled on drive $volume."
        Write-Event -message $message -eventID $eventID_NotEnabled
        
    } elseif ($volume.LockStatus -eq "Locked") {

        $allDecrypted = $false

        $message = "Drive $volume is locked. Cannot check decryption status."
        Write-Event -message $message -eventID $eventID_DriveLocked
    } else {
        $allDecrypted = $false
        $decryptionPercentage = 100 - $bitlockerStatus.EncryptionPercentage
        if ($decryptionPercentage -eq 100) {
            $message = "BitLocker decryption is complete on drive $volume."
            Write-Event -message $message -eventID $eventID_DecryptionComplete

        } else {
            $message = "BitLocker decryption is in progress on drive $volume. Decryption Percentage: $decryptionPercentage%"
            Write-Event -message $message -eventID $eventID_DecryptionInProgress
        }
    }
}   

if ($allDecrypted) {
    $message = "BitLocker decryption is complete on all volumens."
    Write-Event -message $message -eventID $eventID_DecryptionComplete
} else {
    Write-Event -message $message -eventID $eventID_DecryptionInProgress
}