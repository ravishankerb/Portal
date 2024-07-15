Add-Type -AssemblyName System.Web

$MigrationConfig = Import-LocalizedData -BaseDirectory "C:\ProgramData\AADMigration\scripts\" -FileName "MigrationConfig.psd1"

$ClientId = $MigrationConfig.ClientId
$ClientSecret = $MigrationConfig.ClientSecret
$KeyVaultName = $MigrationConfig.KeyVaultName
$TenantID = $MigrationConfig.TenantID

$containerId = $MigrationConfig.ContainerId
$databaseId = $MigrationConfig.DatabaseId
$CosmosDBAccount = $MigrationConfig.CosmosDBAccount
$MasterKey = $MigrationConfig.MasterKey


$endpoint = "https://$CosmosDBAccount.documents.azure.com:443/"
$KeyType = "master"
$TokenVersion = "1.0"
$date = Get-Date
$utcDate = $date.ToUniversalTime()
$xDate = $utcDate.ToString('r', [System.Globalization.CultureInfo]::InvariantCulture)

$itemResourceType = "docs"
$itemResourceId = "dbs/"+$databaseId+"/colls/"+$containerId

$itemResourceLink = "dbs/"+$databaseId+"/colls/"+$containerId+"/docs"
$verbMethod = "POST"

$requestUri = "$endpoint$itemResourceLink"

 
function Get-KeyVaultSecret {
    param(
        
        [string]$SecretName
    )

    # Authenticate using the client credentials flow
    $body = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = "https://vault.azure.net/.default"
    }

    $authResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -ContentType "application/x-www-form-urlencoded" -Body $body

    $accessToken = $authResponse.access_token
    
    # Retrieve the secret from KeyVault
    $keyVaultUri = "https://$KeyVaultName.vault.azure.net"
    $secretUri = "$keyVaultUri/secrets/$($SecretName)?api-version=7.1"
        
    
    $headers = @{
        Authorization = "Bearer $accessToken"
    }

    $secretResponse = Invoke-RestMethod -Method Get -Uri $secretUri -Headers $headers

    # Output the secret value
    $secretValue = $secretResponse.value

    return $secretValue
}

Function Generate-MasterKeyAuthorizationSignature{

    [CmdletBinding()]

    param (

        [string] $Verb,
        [string] $ResourceId,
        [string] $ResourceType,
        [string] $Date,
        [string] $MasterKey,
    	[String] $KeyType,
        [String] $TokenVersion
    )

    $cosmosmasterkey = Get-KeyVaultSecret $MasterKey
    $keyBytes = [System.Convert]::FromBase64String($cosmosmasterkey)

    $sigCleartext = @($Verb.ToLower() + "`n" + $ResourceType.ToLower() + "`n" + $ResourceId + "`n" + $Date.ToString().ToLower() + "`n" + "" + "`n")
	
    $bytesSigClear = [Text.Encoding]::UTF8.GetBytes($sigCleartext)

    $hmacsha = new-object -TypeName System.Security.Cryptography.HMACSHA256 -ArgumentList (, $keyBytes)

    $hash = $hmacsha.ComputeHash($bytesSigClear) 

    $signature = [System.Convert]::ToBase64String($hash)

    $key = [System.Web.HttpUtility]::UrlEncode('type='+$KeyType+'&ver='+$TokenVersion+'&sig=' + $signature)

    return $key
}

Function Insert-MigrationStatus{

   param (
           
        [string] $status,
        [string] $details,
        [string] $source,
        [string] $severity,
        [string] $step
       
    )

    $authKey = Generate-MasterKeyAuthorizationSignature -Verb $verbMethod -ResourceId $itemResourceId -ResourceType $itemResourceType -Date $xDate -MasterKey $MasterKey -KeyType $KeyType -TokenVersion $TokenVersion

    $Dsregcmd = New-Object PSObject ; Dsregcmd /status | Where {$_ -match ' : '}|ForEach {$Item = $_.Trim() -split '\s:\s'; $Dsregcmd|Add-Member -MemberType NoteProperty -Name $($Item[0] -replace '[:\s]','') -Value $Item[1] -EA SilentlyContinue}
    $deviceName = $Dsregcmd.DeviceName
    $deviceId = $Dsregcmd.DeviceId
    $userId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

    $itemId = New-Guid
    $document = @{
        id = $itemId
        deviceName = $deviceName
        deviceid = $deviceId
        userId = $userId
        migrationStatus = @(
            @{
                timestamp = (Get-Date).ToString("o")
                status = $status
                details = $details
                eventSource = $source
                severity = $severity
                
            }
        )
        createdAt = (Get-Date).ToString("o")
        updatedAt = (Get-Date).ToString("o")
    } | ConvertTo-Json -Depth 10

    $partitionkey = "[""$(($document |ConvertFrom-Json).deviceid)""]"

    $header = @{

            "authorization"         = "$authKey"
            "x-ms-version"          = "2018-12-31";
            "Cache-Control"         = "no-cache";
            "x-ms-date"             = "$xDate";
            "Accept"                = "application/json";
            "x-ms-documentdb-partitionkey" = $partitionkey
        }



    try {
        $result = Invoke-RestMethod -Uri $requestUri -Headers $header -Method POST -ContentType "application/json" -Body $document
        
        return "CreateItemSuccess";
    }
    catch {
        # Dig into the exception to get the Response details.
        # Note that value__ is not a typo.
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "Exception Message:" $_.Exception.Message
	    echo $_.Exception|format-list -force
    }
}
