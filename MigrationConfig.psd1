@{

	MigrationPath = "C:\ProgramData\AADMigration"
	UseOneDriveKFM = $True
	InstallOneDrive = $True
	TenantID = "d94c29a2-bb01-401d-962a-64d615f12421"
	DeferDeadline = "10/25/2023 18:00:00"
	DeferTimes = ""
	StartBoundary = "2022-08-20T00:00:00"
	
	ProvisioningPack = "AAD Join.ppkg"

	#Key for retrieving username
	TempUserKey = "TempUsername"
	#Key for retrieving password
	TempPassKey = "TempUserPassword"
	#Key for retrieving DomainLeaver
	DomainLeaverKey = "DomainLeaverUser"
	#Key for retrieving password
	DomainLeaverPassKey = "DomainLeaverPassword"
	
	#Entra ID application for connecting to KeyVault
	ClientId = "a711f96d-1219-48dc-b880-53a4371d4b0b"
	ClientSecret = "LDX8Q~3AW~4goXMFxTB0tZ9YhhvLZPwKEAfGubAk"
	KeyVaultName = "AADMigration"

	#cosmos db variables
	DatabaseId = "migrationlogs"
	ContainerId = "devicemigration"
	CosmosDBAccount = "aadusermigration"

	#Key for getting MasterKey for Cosmos DB from KeyVault
	MasterKey = "CosmosMasterKey"

}