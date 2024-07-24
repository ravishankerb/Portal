Start-Transcript -Path C:\ProgramData\AADMigration\Logs\AD2AADJ-R2.txt -Append -Verbose
$MigrationPath = "C:\ProgramData\AADMigration"
. $MigrationPath\Scripts\LogMigrationStatus.ps1

$clientId = $MigrationConfig.ClientId
$clientSecret = $MigrationConfig.ClientSecret
$tenantID = $MigrationConfig.TenantID

#Block user input, load user32.dll and set block input to true
$code = @"
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
"@ 

$userInput = Add-Type -MemberDefinition $code -Name Blocker -Namespace UserInput -PassThru

$null = $userInput::BlockInput($true)

#Display form with user input block message
[void][reflection.assembly]::loadwithpartialname("system.drawing")
[void][reflection.assembly]::loadwithpartialname("system.Windows.Forms")
$file = (get-item "C:\ProgramData\AADMigration\Files\MigrationInProgress.bmp")
$img = [System.Drawing.Image]::Fromfile((get-item $file))

[System.Windows.Forms.Application]::EnableVisualStyles()
$form = new-object Windows.Forms.Form
$form.Text = "Migration in Progress"
$form.WindowState = 'Maximized'
$form.BackColor = "#000000"
$form.topmost = $true

$pictureBox = new-object Windows.Forms.PictureBox
$pictureBox.Width =  $img.Size.Width;
$pictureBox.Height =  $img.Size.Height;
$pictureBox.Dock = "Fill"
$pictureBox.SizeMode = "StretchImage"


$pictureBox.Image = $img;
$form.controls.add($pictureBox)
$form.Add_Shown( { $form.Activate() } )
$form.Show();


#Function to set registry values
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

#Write-Output "Writing Run Once for Post Reboot" 
<# #Set RunOnce key for next logon
$RegKeyPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
$RegValName = "NextRun"
$RegValType = "String"
$RegValData = 'C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe -executionPolicy Unrestricted -File ' + "C:\ProgramData\AADMigration\Scripts\PostRunOnce3.ps1"

Set-RegistryValue $RegKeyPath $RegValName $RegValType $RegValData #>

#NextRun key requires admin rights on logon. Changing to run PostRunOnce3 as Scheduled task on user login. 
#Create Scheduled task to launch interactive migration task
$TaskPath = "AAD Migration"
$TaskName = "Run Post-migration cleanup"
$ScriptPath = "C:\ProgramData\AADMigration\Scripts"
$ScriptName = "PostRunOnce3.ps1"
$arguments = "-executionpolicy Bypass -file $ScriptPath\$ScriptName"

$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument $arguments

$trigger = New-ScheduledTaskTrigger -AtLogOn 

$principal = New-ScheduledTaskPrincipal -UserId SYSTEM -RunLevel Highest 

$Task = Register-ScheduledTask -principal $principal -Action $Action -Trigger $Trigger -TaskName $TaskName -Description "Run post AAD Migration cleanup" -TaskPath $TaskPath


#endregion functions
#region execute

Write-Output "Setting registry key to disable autoAdminLogon" 
#Disable Auto logon
$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$RegValName = "AutoAdminLogon"
$RegValType = "DWORD"
$RegValData = "0"

Set-RegistryValue $RegKeyPath $RegValName $RegValType $RegValData

Write-Output "Setting key to not show last logged in user" 
#Don't show last logged in user
$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\"
$RegValName = "dontdisplaylastusername"
$RegValType = "DWORD"
$RegValData = "1"

Set-RegistryValue $RegKeyPath $RegValName $RegValType $RegValData

Write-Output "Setting legal notice caption" 
#Set logal notice caption in registry
$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\"
$RegValName = "legalnoticecaption"
$RegValType = "String"
$RegValData = "Migration Completed"

Set-RegistryValue $RegKeyPath $RegValName $RegValType $RegValData

Write-Output "Setting legal notice text" 
#Set legal notice text in registry
$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\"
$RegValName = "legalnoticetext"
$RegValType = "String"
$RegValData = "This PC has been migrated to Azure Active Directory. Please log in to Windows using your email address and password."

Set-RegistryValue $RegKeyPath $RegValName $RegValType $RegValData

# Get an access token
function Get-AccessToken {
    $body = @{
        client_id     = $clientId
        scope         = "https://graph.microsoft.com/.default"
        client_secret = $clientSecret
        grant_type    = "client_credentials"
    }

    $response = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Method Post -ContentType "application/x-www-form-urlencoded" -Body $body
    return $response.access_token
}

$accessToken = Get-AccessToken

# Set primary user
function Set-PrimaryUser {
    param (
        [string]$deviceId,
        [string]$newPrimaryUser
    )

    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$deviceId/assignUser"
    $body = @{
        userPrincipalName = $newPrimaryUser
    } | ConvertTo-Json

    $headers = @{
        Authorization = "Bearer $accessToken"
        ContentType   = "application/json"
    }

    Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
}

# Get list of managed devices
function Get-ManagedDevices {
    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"
    
    $headers = @{
        Authorization = "Bearer $accessToken"
    }

    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
    return $response.value
}

$managedDevices = Get-ManagedDevices

# Find the device ID for the current device
$currentDevice = $managedDevices | Where-Object { $_.deviceName -eq $env:COMPUTERNAME }

if ($currentDevice) {
    Write-Output "Current Device Name: $($currentDevice.deviceName), Device ID: $($currentDevice.id)"
    
    Insert-MigrationStatus "Post Migration" "Changing primary user for $currentDevice.id" "PostRunOnce2.ps1" "Info"
} else {
    Write-Output "Current device ($currentDeviceName) not found in managed devices."
}
# Execute the function
Set-PrimaryUser -deviceId $currentDevice.id -newPrimaryUser "$env:USERNAME@m365x47992235.onmicrosoft.com"

Insert-MigrationStatus "Post Migration" "Device Migrated to Entra" "PostRunOnce2.ps1" "Info"

#Remove scheduled tasks. If we don't remove them now, the user may be prompted to restart the migration on the next logon.
<# #Delete scheduled tasks created for migration
$taskPath = "AAD Migration"
$tasks = Get-ScheduledTask -TaskPath "\$taskpath\"
ForEach($Task in $Tasks){

    Unregister-ScheduledTask -TaskName $Task.TaskName -Confirm:$false
    
} #>

Stop-Transcript

$Null = $userInput::BlockInput($false)

$form.Close()

restart-computer

