$MigrationPath = "C:\ProgramData\AADMigration"
# Define the interval (in minutes) before re-prompting the user
$deferInterval = 10
# Define the maximum number of deferrals
$maxDefers = 3
$deferCount = 0

# Function to prompt the user
function Prompt-Restart {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $result = [System.Windows.Forms.MessageBox]::Show($message, "Restart Required", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    return $result
}


# Function to create the scheduled task
function Create-RestartScheduledTask {
    $TaskPath = "AAD Migration"
    $scriptPath = "$MigrationPath\Scripts\RestartComputerScheduler.ps1" # Path to this script
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes($deferInterval) -RepetitionInterval (New-TimeSpan -Minutes $deferInterval) -RepetitionDuration (New-TimeSpan -Hours 56 -Minutes 55)
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME 
    Register-ScheduledTask -TaskName "Restart Prompt Task" -TaskPath $TaskPath -Action $action -Trigger $trigger -Principal $principal -Description "Prompt user to restart computer with option to defer" -ErrorAction SilentlyContinue

}

$message = "Your computer needs to restart. Do you want to restart now?"

if ($MyInvocation.MyCommand.Path -eq $PSCommandPath) {
    Write-Host "This script is meant to be dot-sourced or imported, not executed directly."
    exit
}

# Main script logic
while ($deferCount -lt $maxDefers) {
    $userChoice = Prompt-Restart
    if ($userChoice -eq [System.Windows.Forms.DialogResult]::Yes) {
        Restart-Computer -Force
        break
    } else {
        Write-Host "User chose to defer the restart. Will prompt again in $deferInterval minutes."
        $deferCount++
        if ($deferCount -eq 1) {
            Create-RestartScheduledTask
        }
        Start-Sleep -Seconds ($deferInterval * 60)
    }
}

# If max defers reached, force restart
if ($deferCount -ge $maxDefers) {
    Write-Host "Maximum deferrals reached. Restarting the computer now."
    Restart-Computer -Force
}
