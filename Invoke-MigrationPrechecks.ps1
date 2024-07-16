$MigrationPath = "C:\ProgramData\AADMigration"
. $MigrationPath\Scripts\LogMigrationStatus.ps1

$oneDriveInstalled = $false
$vcRuntimeInstalled = $false

$vcRuntimeInstalled = Test-VCRuntimeInstalled 

$oneDriveInstalled = Test-OneDriveInstalled 

Insert-PreCheckStatus $oneDriveInstalled $vcRuntimeInstalled

function Test-OneDriveInstalled {

    $ODRegKey = "HKLM:\SOFTWARE\Microsoft\OneDrive"

    $InstalledVer = Get-ItemPropertyValue -Path $ODRegKey -Name Version 
    if (!($?))
    {
        $oneDriveInstalled = $false
       
    }
    else
    {
        $oneDriveInstalled = $true
       
    }      
    return $oneDriveInstalled
}

# Function to check if a specific VC runtime is installed
function Test-VCRuntimeInstalled {
    param (
        [string]$displayName
    )

    $installed = $false
    $uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $uninstallKey64 = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"

   
    # Check 64-bit registry path
    if (-not $installed) {
        $installedApps64 = Get-ItemProperty -Path "$uninstallKey64\*" -ErrorAction SilentlyContinue
        foreach ($app in $installedApps64) {
            if ($app.DisplayName -like "*$displayName*") {
                $installed = $true
                break
            }
        }
    }

    return $installed
}

# List of VC runtimes to check
$vcRuntimes = @(
    "Microsoft Visual C++ 2010 Redistributable",
    "Microsoft Visual C++ 2012 Redistributable",
    "Microsoft Visual C++ 2013 Redistributable",
    "Microsoft Visual C++ 2015 Redistributable",
    "Microsoft Visual C++ 2017 Redistributable",
    "Microsoft Visual C++ 2019 Redistributable"
)

foreach ($runtime in $vcRuntimes) {
    if (Test-VCRuntimeInstalled -displayName $runtime) {
        Write-Output "$runtime is installed."
    } else {
        Write-Output "$runtime is not installed."
    }
}
