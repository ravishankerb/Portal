$MigrationPath = "C:\ProgramData\AADMigration"
. $MigrationPath\Scripts\LogMigrationStatus.ps1

# Define the drive letter and event log parameters
$driveLetter = "C:"
$eventLogName = "Application"
$eventSource = "AAD_Migration_Script"
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
$bitlockerStatus = Get-BitLockerVolume -MountPoint $driveLetter

if ($bitlockerStatus.ProtectionStatus -eq "Off") {
    $message = "BitLocker is not enabled on drive $driveLetter."
    Write-Event -message $message -eventID $eventID_DecryptionComplete

    Start-ScheduledTask -TaskName "AADM Launch PSADT for Interactive Migration" -TaskPath '\AAD Migration\'
    Start-Sleep -Seconds 5
} elseif ($bitlockerStatus.LockStatus -eq "Locked") {
    $message = "Drive $driveLetter is locked. Cannot check decryption status."
    Write-Event -message $message -eventID $eventID_DriveLocked
} else {
    $decryptionPercentage = 100 - $bitlockerStatus.EncryptionPercentage
    if ($decryptionPercentage -eq 100) {
        $message = "BitLocker decryption is complete on drive $driveLetter."
        Write-Event -message $message -eventID $eventID_DecryptionComplete

        Start-ScheduledTask -TaskName "AADM Launch PSADT for Interactive Migration" -TaskPath '\AAD Migration\'
        Start-Sleep -Seconds 5
    } else {
        $message = "BitLocker decryption is in progress on drive $driveLetter. Decryption Percentage: $decryptionPercentage%"
        Write-Event -message $message -eventID $eventID_DecryptionInProgress
    }
}
