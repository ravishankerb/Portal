$MigrationPath = "C:\ProgramData\AADMigration"
Start-Transcript -Path C:\ProgramData\AADMigration\Logs\AD2AADJ-Prep.txt -Append -Force

#Expand AAD Migration zip file to ProgramData
Expand-Archive "$PSScriptRoot\AADMigration.zip" -DestinationPath C:\ProgramData -Force
. $MigrationPath\Scripts\LogMigrationStatus.ps1

$MigrationConfig = Import-LocalizedData -BaseDirectory "$MigrationPath\Scripts" -FileName "MigrationConfig.psd1"
$MigrationPath = $MigrationConfig.MigrationPath
$TenantID = $MigrationConfig.TenantID
$OneDriveKFM = $MigrationConfig.UseOneDriveKFM
$InstallOneDrive = $MigrationConfig.InstallOneDrive
$StartBoundary = $MigrationConfig.StartBoundary
$DeferInterval = 10
$MaxDefers = 3

function Set-RegistryValue {

    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$True)]
        [string]$RegKeyPath,
        [Parameter(Mandatory=$True)]
        [string]$RegValueName,
        [Parameter(Mandatory=$True)]
        [string]$RegValType,
        [Parameter(Mandatory=$True)]
        [string]$RegValData
    )


    #Test to see if Edge key exists, if it does not exist create it
    $RegKeyPathExists = Test-Path $RegKeyPath
    Write-Host "$RegKeyPath Exists"
    if (!$RegKeyPathExists) {
        New-Item -Path $RegKeyPath -Force | Out-Null
    }

    #Check to see if value exists
    Try {
             $CurrentValue = Get-ItemPropertyValue -Path $RegKeyPath -Name $RegValName 
    } Catch {       
        #If value does not exist an error would be thrown, catch error and create key
        Set-ItemProperty -Path $RegKeyPath  -Name $RegValName -Type $RegValType -Value $RegValData -Force
    }


    IF($CurrentValue -ne $RegValData){
        #If value exists but data is wrong, update the value
        Set-ItemProperty -Path $RegKeyPath  -Name $RegValName -Type $RegValType -Value $RegValData -Force
    } 

} 

function Set-ODKFMSettings{

    #Set registry values for enabling KFM to set tenant
    $RegKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
    $RegValName = "AllowTenantList"
    $RegValType = "STRING"
    $RegValData = $TenantID

    Set-RegistryValue $RegKeyPath $RegValName $RegValType $RegValData


    $RegKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
    $RegValName = "SilentAccountConfig"
    $RegValType = "DWORD"
    $RegValData = "1"

    Set-RegistryValue $RegKeyPath $RegValName $RegValType $RegValData

    $RegKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
    $RegValName = "KFMOptInWithWizard"
    $RegValType = "STRING"
    $RegValData = $TenantID

    Set-RegistryValue $RegKeyPath $RegValName $RegValType $RegValData


    $RegKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
    $RegValName = "KFMSilentOptIn"
    $RegValType = "STRING"
    $RegValData = $TenantID

    Set-RegistryValue $RegKeyPath $RegValName $RegValType $RegValData

    $RegKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
    $RegValName = "KFMSilentOptInDesktop"
    $RegValType = "DWORD"
    $RegValData = "1"

    Set-RegistryValue $RegKeyPath $RegValName $RegValType $RegValData
    $RegKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
    $RegValName = "KFMSilentOptInDocuments"
    $RegValType = "DWORD"
    $RegValData = "1"

    Set-RegistryValue $RegKeyPath $RegValName $RegValType $RegValData

    $RegKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
    $RegValName = "KFMSilentOptInPictures"
    $RegValType = "DWORD"
    $RegValData = "1"

    Set-RegistryValue $RegKeyPath $RegValName $RegValType $RegValData

    #Create EventLog Source
    $sourceExists = $false
    try
    {
        $sourceExists = [System.Diagnostics.EventLog]::SourceExists($SourceName)
        $sourceExists = $rue
    }
    catch
    {
    }
    if ($sourceExists = $false)
    {
        New-EventLog -LogName 'Application' -Source 'AAD_Migration_Script' -ErrorAction Stop        
    }

    #Create scheduled task to check OneDrive sync status
    $TaskPath = "AAD Migration"
    $TaskName = "AADM Get OneDrive Sync Status"
    $ScriptPath = "C:\ProgramData\AADMigration\Scripts"
    $ScriptName = "Check-OneDriveSyncStatus.ps1"
    $arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -file $ScriptPath\$ScriptName"

    $action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument $arguments

    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $trigger.Delay = 'PT1M'

    $principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" 

    $Task = Register-ScheduledTask -Principal $principal -Action $Action -Trigger $Trigger -TaskName $TaskName -Description "Get current OneDrive Sync Status and write to event log" -TaskPath $TaskPath
    $Task.Triggers.repetition.Duration = "P1D"
    $Task.Triggers.repetition.Interval  = "PT30M"
    $Task | Set-ScheduledTask

    Insert-MigrationStatus "Preparing Device" "Created task to get OneDrive status" "Prepare-DeviceMigration.ps1" "Info"

}

Function Install-VCRuntime{

    If(Test-Path -Path "$MigrationPath\Files\VC_redist.x64.exe"){
    
        $VcRuntimeSetupVersion = (Get-ChildItem -Path "$MigrationPath\Files\VC_redist.x64.exe").VersionInfo.FileVersion

    }

    If(!$VcRuntimeSetupVersion){

        Invoke-WebRequest "https://aka.ms/vs/17/release/vc_redist.x64.exe" -OutFile "$MigrationPath\Files\VC_redist.x64.exe"  
        $VcRuntimeSetupVersion = (Get-ChildItem -Path "$MigrationPath\Files\VC_redist.x64.exe").VersionInfo.FileVersion

    }
        
    $uninstallKey64 = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"

    $installedApps64 = Get-ItemProperty -Path "$uninstallKey64\*" -ErrorAction SilentlyContinue
    if (!($?))
    {
        Insert-MigrationStatus "Preparing Device" ($Error[0].ToString() + $Error[0].Exception.StackTrace) "Prepare-DeviceMigration.ps1" "Error"
    }

    $installed = $false
    foreach ($app in $installedApps64) {
        if ($app.DisplayName -like "Microsoft Visual C++ 2015-2022 Redistributable (x64) - 14.40.33810") {
            $installed = $true
            break
        }
    }
    if (!$installed)
    {
        #Install VC runtime silently
        $Installer = "$MigrationPath\Files\VC_redist.x64.exe"
        $Arguments = "/q"
        Insert-MigrationStatus "Preparing Device" "Installing VC runtime silently" "Prepare-DeviceMigration.ps1" "Error"

        Start-Process -FilePath $Installer -ArgumentList $Arguments
    }
}

Function Install-OneDrive{

    #Check for OneDrive machine-wide installer, check version number if it exists
    If(Test-Path -Path "$MigrationPath\Files\OneDriveSetup.exe"){
        $ODSetupVersion = (Get-ChildItem -Path "$MigrationPath\Files\OneDriveSetup.exe").VersionInfo.FileVersion
    }

    If(!$ODSetupVersion){

        Invoke-WebRequest "https://go.microsoft.com/fwlink/?linkid=844652" -OutFile "$MigrationPath\Files\OneDriveSetup.exe"  
        $ODSetupVersion = (Get-ChildItem -Path "$MigrationPath\Files\OneDriveSetup.exe").VersionInfo.FileVersion

    }

    $ODRegKey = "HKLM:\SOFTWARE\Microsoft\OneDrive"

    $InstalledVer = Get-ItemPropertyValue -Path $ODRegKey -Name Version -ErrorAction SilentlyContinue
    if (!($?))
    {
        Insert-MigrationStatus "Preparing Device" ($Error[0].ToString() + $Error[0].Exception.StackTrace) "Prepare-DeviceMigration.ps1" "Error"
    }

    If(!($InstalledVer) -or ([System.Version]$InstalledVer -lt [System.Version]$ODSetupVersion)){

        #Install OneDrive setup
        $Installer = "$MigrationPath\Files\OneDriveSetup.exe"
        $Arguments = "/allusers"

        Start-Process -FilePath $Installer -ArgumentList $Arguments
        while (!($InstalledVer) ){
            Write-Output "Installing OneDrive"
            Start-Sleep -Seconds 5  
            $InstalledVer = Get-ItemPropertyValue -Path $ODRegKey -Name Version -ErrorAction SilentlyContinue    
        } 

    } ElseIf($OneDriveKFM) {

        #If OneDrive is already installed, stop the process and restart to kick off KFM sync if required
        $ODProcess = Get-Process OneDrive 

        If($ODProcess){

            $ODProcess | Stop-Process -Confirm:$false -Force
 
            Start-Sleep -Seconds 5  

            $action = New-ScheduledTaskAction -Execute "C:\Program Files\Microsoft Onedrive\OneDrive.exe" 
            $trigger = New-ScheduledTaskTrigger -AtLogOn
            $principal = New-ScheduledTaskPrincipal -UserId (Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -expand UserName)
            $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal
            Register-ScheduledTask OneDriveRemediation -InputObject $task
            Start-ScheduledTask -TaskName OneDriveRemediation
            Start-Sleep -Seconds 5
            Unregister-ScheduledTask -TaskName OneDriveRemediation -Confirm:$false

            Insert-MigrationStatus "Preparing Device" "Created and deleted OneDrive remediation task" "Prepare-DeviceMigration.ps1" "Info"

        }
    }

}

Function New-MigrationTask{

    #Create Scheduled task to launch interactive migration task
    $TaskPath = "AAD Migration"
    $TaskName = "AADM Launch PSADT for Interactive Migration"
    $ScriptPath = "C:\ProgramData\AADMigration\Scripts"
    $ScriptName = "Launch-DeployApplication_SchTask.ps1"
    $arguments = "-executionpolicy Bypass -file $ScriptPath\$ScriptName"

    $action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument $arguments

    $trigger = New-ScheduledTaskTrigger -AtLogOn 
    $trigger.Delay = 'PT1M'
    $trigger.StartBoundary = $StartBoundary

    $principal = New-ScheduledTaskPrincipal -UserId SYSTEM -RunLevel Highest 

    $Task = Register-ScheduledTask -principal $principal -Action $Action -Trigger $Trigger -TaskName $TaskName -Description "AADM Launch PSADT for Interactive Migration" -TaskPath $TaskPath

    Insert-MigrationStatus "Preparing Device" "Created Migration task" "Prepare-DeviceMigration.ps1" "Info"
}

# Function to prompt the user
function Prompt-Restart {
    $message = "Your computer needs to restart. Do you want to restart now?"
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $result = [System.Windows.Forms.MessageBox]::Show($message, "Restart Required", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    return $result
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
    
}

New-MigrationTask

If($OneDriveKFM){

    Set-ODKFMSettings

}

Install-VCRuntime

If($InstallOneDrive){

    Install-OneDrive
}

# Main script logic
do {
    $oneDriveProcess = Get-Process -Name OneDrive -ErrorAction SilentlyContinue
    $oneDriveSignedIn = $true
    if ($oneDriveProcess) {
        
        $Status = & "C:\ProgramData\AADMigration\Scripts\Get-ODStatus.ps1" -ExePath "$MigrationPath\Files"
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive" -Name "SilentAccountConfig" -Value 1

        foreach ($s in $Status) {
            $StatusString = $s.CurrentStateString
            $ServiceName = $s.ServiceName
            $oneDriveUser = "$env:USERDOMAIN\$env:USERNAME"
                      
            if (-not $s.UserName -or $ServiceName -ne "Business1" -or $oneDriveUser -ne $s.UserName) {
                Write-Output "Ignoring event."                   
            }
            else
            {
                Write-Output "Considering event."
                if (-not $StatusString) {
                    Write-Output "OneDrive is not signed in."
                    $oneDriveSignedIn = $false
                    Prompt-OneDriveSignIn
                    
                } else {
                    Write-Output "OneDrive is signed in."
                    $oneDriveSignedIn = $true
                }
            }
        }
    } else {
        Write-Output "OneDrive is not running."
        Start-Process "C:\Program Files\Microsoft OneDrive\OneDrive.exe"
        $oneDriveSignedIn = $false
    }
    Start-Sleep -Seconds 3
} while ($oneDriveSignedIn -eq $false)


$deferCount = 0

# Main script logic
while ($deferCount -lt $MaxDefers) {
    $userChoice = Prompt-Restart
    if ($userChoice -eq [System.Windows.Forms.DialogResult]::Yes) {
        Insert-MigrationStatus "Preparing Device" "User clicked Yes for restart." "Prepare-DeviceMigration.ps1" "Info"
        #Restart-Computer -Force
        break
    } else {
        Write-Host "User chose to defer the restart. Will prompt again in $DeferInterval minutes."
        Insert-MigrationStatus "Preparing Device" "User chose to defer the restart. Will prompt again in $DeferInterval minutes." "Prepare-DeviceMigration.ps1" "Info"
        $deferCount++
        Start-Sleep -Seconds ($DeferInterval * 60)
    }
}

# If max defers reached, force restart
if ($deferCount -ge $MaxDefers) {
    Write-Host "Maximum deferrals reached. Restarting the computer now."
    Insert-MigrationStatus "Preparing Device" "Maximum deferrals reached. Restarting the computer now." "Prepare-DeviceMigration.ps1" "Info"
    #Restart-Computer -Force
}