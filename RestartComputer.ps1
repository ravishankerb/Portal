$MigrationPath = "C:\ProgramData\AADMigration"
$MigrationConfig = Import-LocalizedData -BaseDirectory "$MigrationPath\Scripts" -FileName "MigrationConfig.psd1"
# Define the interval (in minutes) before re-prompting the user
$DeferInterval = $MigrationConfig.StartBoundary
$MaxDefers = $MigrationConfig.MaxDefers
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
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes($DeferInterval) -RepetitionInterval (New-TimeSpan -Minutes $DeferInterval) -RepetitionDuration (New-TimeSpan -Hours 56 -Minutes 55)
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME 
    Register-ScheduledTask -TaskName "Restart Prompt Task" -TaskPath $TaskPath -Action $action -Trigger $trigger -Principal $principal -Description "Prompt user to restart computer with option to defer" -ErrorAction SilentlyContinue

}

$message = "Your computer needs to restart. Do you want to restart now?"

if ($MyInvocation.MyCommand.Path -eq $PSCommandPath) {
    Write-Host "This script is meant to be dot-sourced or imported, not executed directly."
    exit
}

# Main script logic
while ($deferCount -lt $MaxDefers) {
    $userChoice = Prompt-Restart
    if ($userChoice -eq [System.Windows.Forms.DialogResult]::Yes) {
        Disable-ScheduledTask -TaskName "Restart Prompt Task" -TaskPath $TaskPath
        Restart-Computer -Force
        break
    } else {
        Write-Host "User chose to defer the restart. Will prompt again in $DeferInterval minutes."
        $deferCount++
        if ($deferCount -eq 1) {
            Create-RestartScheduledTask
        }
        Start-Sleep -Seconds ($DeferInterval * 60)
    }
}

# If max defers reached, force restart
if ($deferCount -ge $MaxDefers) {
    Write-Host "Maximum deferrals reached. Restarting the computer now."
    Disable-ScheduledTask -TaskName "Restart Prompt Task" -TaskPath $TaskPath
    Restart-Computer -Force
}
