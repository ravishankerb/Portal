# Define the drive letter
$driveLetter = "C:"

# Check if BitLocker is enabled on the drive
$bitlockerStatus = Get-BitLockerVolume -MountPoint $driveLetter

if ($bitlockerStatus.ProtectionStatus -eq "On") {
    Write-Output "BitLocker is enabled on drive $driveLetter. Disabling BitLocker..."

    # Disable BitLocker and start the decryption process in the background
    Disable-BitLocker -MountPoint $driveLetter
    
    Write-Output "BitLocker decryption has been initiated on drive $driveLetter. It will continue to run in the background."
} else {
    Write-Output "BitLocker is not enabled on drive $driveLetter."
}
