
# Get the Windows version information
$osVersion = (Get-ComputerInfo).OsVersion
$Win11 = $false
# Determine if the OS is Windows 10 or Windows 11
if ($osVersion -ge "10.0.22000" -and $osVersion -lt "10.1.0") {
    $Win11 = $true
} elseif ($osVersion -ge "10.0.10240" -and $osVersion -lt "10.0.22000") {
    $Win11 = $false
} else {
    $Win11 = $false
}

if ($Win11 = $true)
{
    $Status = .\Get-ODStatus.ps1 -ExePath C:\ProgramData\AADMigration\Files

    #Create objects with known statuses listed.
    $Success = @( "Synced" )
    $InProgress = @( "Syncing" )
    $Failed = $( "Error" , "Error" , "Paused")
}
else
{
    #Import OneDriveLib.dll to check current OneDrive Sync Status
    Import-Module C:\ProgramData\AADMigration\Files\OneDriveLib.dll
    $Status = Get-ODStatus

    #Create objects with known statuses listed.
    $Success = @( "Shared" , "UpToDate" , "Up To Date" )
    $InProgress = @( "SharedSync" , "Shared Sync" , "Syncing" )
    $Failed = $( "Error" , "ReadOnly" , "Read Only" , "OnDemandOrUnknown" , "On Demand or Unknown" , "Paused")
}



#Multiple OD4B accounts may be found. Consider adding logic to identify correct OD4B. Iterate through all accounts to check status and write to event log.
ForEach($s in $Status){

    if ($Win11 = $true)
    {
        $StatusString = $s.CurrentStateString
        $DisplayName = $s.ServiceName
    }
    else {
        $StatusString = $s.StatusString
        $DisplayName = $s.DisplayName   
    }

    $User = $s.UserName

    If($StatusString -in $Success){ 

        Write-EventLog -LogName 'Application' -Source 'AAD_Migration_Script' -EntryType Information -EventId 1337 `
            -Message "The OneDrive sync status is healthy. The following values were returned: OneDrive Display Name: $DisplayName, User: $User, Status: $StatusString"


    } elseif ($StatusString -in $InProgress) {
        
        Write-EventLog -LogName 'Application' -Source 'AAD_Migration_Script' -EntryType Information -EventId 1338 `
        -Message "The OneDrive sync status is currently syncing. The following values were returned: OneDrive Display Name: $DisplayName, User: $User, Status: $StatusString"

    } elseif ($StatusString -in $Failed) {

        Write-EventLog -LogName 'Application' -Source 'AAD_Migration_Script' -EntryType Information -EventId 1339 `
        -Message "The OneDrive sync status is in a known error state. The following values were returned: OneDrive Display Name: $DisplayName, User: $User, Status: $StatusString"

    } elseif(!($StatusString)){
        
        Write-EventLog -LogName 'Application' -Source 'AAD_Migration_Script' -EntryType Information -EventId 1340 `
        -Message "Unable to get OneDrive Sync Status."

    }

    If(!($StatusString)){

        Write-EventLog -LogName 'Application' -Source 'AAD_Migration_Script' -EntryType Information -EventId 1340 `
            -Message "Unable to get OneDrive Sync Status."


    }

}