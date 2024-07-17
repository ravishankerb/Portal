$MigrationPath = "C:\ProgramData\AADMigration"
$oneDriveSignedIn = $false
 
# Function to check OneDrive status
function Get-OneDriveStatus {
    $oneDriveProcess = Get-Process -Name OneDrive -ErrorAction SilentlyContinue
    if ($oneDriveProcess) {
        Write-Output "OneDrive is running."
        
        #$Status = C:\ProgramData\AADMigration\Scripts\Get-ODStatus.ps1 -ExePath C:\ProgramData\AADMigration\Files
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive" -Name "SilentAccountConfig" -Value 1
        ForEach($s in $Status){
            $StatusString = $s.StatusString
            $DisplayName = $s.DisplayName   
            $s.UserName   
            If(!($StatusString)){           
                Write-Output "OneDrive is signed in."
                return $true
            } else {
                Write-Output "OneDrive is not signed in."
                return $false
            }
        }
        
    } else {
        Write-Output "OneDrive is not running."
        return $false
    }
}

# Function to prompt user to sign in to OneDrive
function Prompt-OneDriveSignIn {
    Add-Type -AssemblyName "System.Windows.Forms"
    Add-Type -AssemblyName "Microsoft.VisualBasic"

    $caption = "OneDrive Sign-In Required"
    $message = "Please sign in to OneDrive to ensure your files are synced."
    $buttons = [System.Windows.Forms.MessageBoxButtons]::OK
    $icon = [System.Windows.Forms.MessageBoxIcon]::Warning
    
    $result = [System.Windows.Forms.MessageBox]::Show($message, $caption, $buttons, $icon)   
      
    Start-Process "C:\Program Files\Microsoft OneDrive\OneDrive.exe"
}

# Main script logic
Get-OneDriveStatus

if (-not $oneDriveSignedIn) {
    Write-Output "OneDrive is not running."
    Prompt-OneDriveSignIn
}

# Schedule a task to check OneDrive status periodically
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-File C:\Development\Scripts\OneDriveCheck.ps1'
$trigger = New-ScheduledTaskTrigger -Daily -At 09:00AM
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName "OneDriveSignInCheck" -Action $action -Trigger $trigger -Principal $principal -Settings $settings
