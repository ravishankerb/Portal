<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of an application(s).
- The script either performs an "Install" deployment type or an "Uninstall" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

PSApppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2024 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham and Muhammad Mashwani).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType

The type of deployment to perform. Default is: Install.

.PARAMETER DeployMode

Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru

Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode

Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging

Disables logging to file for the script. Default is: $false.

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"

.EXAMPLE

Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
- 70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1

.LINK

https://psappdeploytoolkit.com
#>


[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [String]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [String]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false
)

Try {
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    } Catch {
    }

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [String]$appVendor = ''
    [String]$appName = ''
    [String]$appVersion = ''
    [String]$appArch = ''
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [String]$appScriptDate = 'XX/XX/20XX'
    [String]$appScriptAuthor = '<author name>'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [string]$installName = 'Azure Active Directory Migration'
	[string]$installTitle = 'AAD Migration Utility'

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
    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [Int32]$mainExitCode = 0

    ## Variables: Script
    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.10.1'
    [String]$deployAppScriptDate = '05/03/2024'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    }
    Else {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [String]$moduleAppDeployToolkitMain = "$MigrationPath\Toolkit\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging) {
            . $moduleAppDeployToolkitMain -DisableLogging
        }
        Else {
            . $moduleAppDeployToolkitMain
        }
    }
    Catch {
        If ($mainExitCode -eq 0) {
            [Int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') {
            $script:ExitCode = $mainExitCode; Exit
        }
        Else {
            Exit $mainExitCode
        }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'
        
        $TaskPath = "\AAD Migration\"
        $TaskName = "AADM Launch Device Migration"

        Function New-DeviceMigrationTask{

            $ScriptPath = "C:\Prod"
            $ScriptName = "Prepare-DeviceMigration.ps1"
            $arguments = "-process:explorer.exe %SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -file Prepare-DeviceMigration.ps1"

            $action = New-ScheduledTaskAction -Execute "$MigrationPath\Files\ServiceUI.exe" -Argument $arguments

            $trigger = New-ScheduledTaskTrigger -AtLogOn
            $trigger.Delay = 'PT1M'

            $principal = New-ScheduledTaskPrincipal -UserId SYSTEM -RunLevel Highest 

            $Task = Register-ScheduledTask -Principal $principal -Action $Action -Trigger $Trigger -TaskName $TaskName -Description "Get current OneDrive Sync Status and write to event log" -TaskPath $TaskPath
            $Task.Triggers.repetition.Duration = "P1D"
            $Task.Triggers.repetition.Interval  = "PT30M"
            $Task.Actions[0].WorkingDirectory = $ScriptPath
            $Task | Set-ScheduledTask
        }
        $taskExists = $false
        try {
            $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction Stop
            $taskExists = $true
            
        } catch {
            
        }
        if (-not $taskExists) {
            New-DeviceMigrationTask
        }

        ## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
        Show-InstallationWelcome -CloseApps 'iexplore' -AllowDefer -DeferTimes 10 -DeferDeadline "10/25/2024 18:00:00" -CheckDiskSpace -PersistPrompt

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Installation tasks here>


        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        ## Handle Zero-Config MSI Installations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) {
                $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ }
            }
        }

        ## <Perform Installation tasks here>
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
            $Task.Actions[0].WorkingDirectory = $ScriptPath
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

            try
            {
                $InstalledVer = Get-ItemPropertyValue -Path $ODRegKey -Name Version -ErrorAction SilentlyContinue
            }
            catch
            {
                if (!($?))
                {
                    Insert-MigrationStatus "Preparing Device" ($Error[0].ToString() + $Error[0].Exception.StackTrace) "Prepare-DeviceMigration.ps1" "Error"
                }
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

        Function New-BitlockerDecryptStatusTask{

            $TaskPath = "AAD Migration"
            $TaskName = "AADM Get Bitlocker Decrypt Status"
            $ScriptPath = "C:\ProgramData\AADMigration\Scripts"
            $ScriptName = "CheckBitLockerDecryptionStatus.ps1"
            $arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -file $ScriptPath\$ScriptName"

            $action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument $arguments

            $trigger = New-ScheduledTaskTrigger -AtLogOn
            $trigger.Delay = 'PT1M'

            $principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" 

            $Task = Register-ScheduledTask -Principal $principal -Action $Action -Trigger $Trigger -TaskName $TaskName -Description "Get current OneDrive Sync Status and write to event log" -TaskPath $TaskPath
            $Task.Triggers.repetition.Duration = "P1D"
            $Task.Triggers.repetition.Interval  = "PT30M"
            $Task.Actions[0].WorkingDirectory = $ScriptPath
            $Task | Set-ScheduledTask

            Insert-MigrationStatus "Preparing Device" "Created task to get Bitlocker decrypt status" "Prepare-DeviceMigration.ps1" "Info"
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

        New-BitlockerDecryptStatusTask

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


       

        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>

        ## Display a message at the end of the install
        If (-not $useDefaultMsi) {
            Show-InstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -Icon Information -NoWait
        }
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Uninstallation tasks here>


        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        ## Handle Zero-Config MSI Uninstallations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }

        ## <Perform Uninstallation tasks here>
        $TaskPath = "\AAD Migration\"
        $TaskName = "AADM Launch Device Migration"
        # Check if the scheduled task exists
        $taskExists = $false
        try {
            $task = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction Stop
            $taskExists = $true
        } catch {
        }

        # Delete the scheduled task if it exists
        if ($taskExists) {
            Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Confirm:$false
        }


        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'

        ## <Perform Post-Uninstallation tasks here>


    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Repair tasks here>

        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'

        ## Handle Zero-Config MSI Repairs
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }
        ## <Perform Repair tasks here>

        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [String]$installPhase = 'Post-Repair'

        ## <Perform Post-Repair tasks here>


    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
