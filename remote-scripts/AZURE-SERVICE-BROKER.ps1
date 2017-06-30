<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()

try
{
    $parameters = $currentTestData.parameters
    $location = $xmlConfig.config.Azure.General.Location
    $subscriptionID = $xmlConfig.config.Azure.General.SubscriptionID
    $environment = $xmlConfig.config.Azure.General.Environment
    $spTenantID = $env:ServicePrincipalTenantID
    $spClientID = $env:ServicePrincipalClientID
    $spClientSecret = $env:ServicePrincipalkey
    $resourceGroupName = "rg-sqlserver-$(get-random)"
    $sqlServerName = "server-$(get-random)"
    [System.Collections.ArrayList]$locationlist = (Get-AzureRmLocation | select Location).location
    $locationlist.Remove('koreasouth')
    $locationlist.Remove('koreacentral')
    $locationofdatabase = $locationlist | Get-Random
    foreach ($file in $currentTestData.files.Split(","))
    {
        LogMsg "Update test script $file"
        $contents = Get-Content .\remote-scripts\$file -raw
        $contents -replace 'REPLACE_WITH_RESOURCEGROUPNAME',$resourceGroupName`
        -replace 'REPLACE_WITH_LOCATION',$locationofdatabase`
        -replace 'REPLACE_WITH_ENVIRONMENT',$environment`
        -replace 'REPLACE_WITH_SUBSCRIPTIONID',$subscriptionID`
        -replace 'REPLACE_WITH_TENANTID',$spTenantID`
        -replace 'REPLACE_WITH_CLIENTID',$spClientID`
        -replace 'REPLACE_WITH_CLIENTSECRET',$spClientSecret`
        -replace 'REPLACE_WITH_SERVERNAME',$sqlServerName | out-file $file -Encoding default
    }

    if($global:RunnerMode -eq "Runner")
    {
        $out = .\remote-scripts\bosh-cf-template-handler.ps1 ..\azure-quickstart-templates\bosh-setup\azuredeploy.json $parameters.environment runner
    }

    if($global:RunnerMode -eq "OnDemand" -and $global:OnDemandVersInfo -ne $null)
    {
        $out = .\remote-scripts\bosh-cf-template-handler.ps1 ..\azure-quickstart-templates\bosh-setup\azuredeploy.json $parameters.environment ondemand $global:OnDemandVersInfo
    }

    if(Test-Path .\azuredeploy.parameters.json)
    {
        Remove-Item .\azuredeploy.parameters.json
    }

    # update template parameter file 
    LogMsg 'update template parameter file '
    $jsonfile =  Get-Content ..\azure-quickstart-templates\bosh-setup\azuredeploy.parameters.json -Raw | ConvertFrom-Json
    $curtime = Get-Date
    $timestr = "-" + $curtime.Month + "-" +  $curtime.Day  + "-" + $curtime.Hour + "-" + $curtime.Minute + "-" + $curtime.Second
	$vmName = $parameters.vmName + $timestr
    $jsonfile.parameters.vmName.value = $vmName
    $jsonfile.parameters.adminUsername.value = $parameters.adminUsername
    $jsonfile.parameters.sshKeyData.value = $parameters.sshKeyData
    $jsonfile.parameters.environment.value = $parameters.environment
    $jsonfile.parameters.tenantID.value = $parameters.tenantID
    $jsonfile.parameters.clientID.value = $parameters.clientID
    $jsonfile.parameters.clientSecret.value = $parameters.clientSecret
    $jsonfile.parameters.autoDeployBosh.value = $parameters.autoDeployBosh
    
    # save template parameter file
    $jsonfile | ConvertTo-Json | Out-File .\azuredeploy.parameters.json

    $isDeployed = CreateAllRGDeploymentsWithTempParameters -templateName $currentTestData.setupType -location $location -TemplateFile ..\azure-quickstart-templates\bosh-setup\azuredeploy.json  -TemplateParameterFile .\azuredeploy.parameters.json
	
    if ($isDeployed[0] -ne $True)
    {
        throw 'deploy resouces with error, please check.'
    }

    $port = 22
    $global:sshKey = "cf_devbox_privatekey.ppk"
	$user = $parameters.adminUsername
	$publicIPResourceID = (Get-AzureRmVM -ResourceGroupName $isDeployed[1] | where {$_.Name -match $($parameters.vmName)} | Get-AzureRmNetworkInterface).IpConfigurations[0].PublicIpAddress.id
	$ip = (Get-AzureRmResource -ResourceId $publicIPResourceID).Properties.ipAddress

	RemoteCopy -uploadTo $ip -port $port -files $currentTestData.files -username $user -password $password -upload -usePrivateKey -doNotCompress 
	$out = RunLinuxCmd -username $user -password $password -ip $ip -port $port -command "bosh -v" -usePrivateKey
    LogMsg "Current bosh cli version: $out"
    if($global:RunnerMode -eq "Runner")
    {
        LogMsg "Runner mode, Update bosh cli to the latest"
		RunLinuxCmd -username $user -password $password -ip $ip -port $port -command "sudo gem install bosh_cli --no-ri --no-rdoc" -usePrivateKey
        $out = RunLinuxCmd -username $user -password $password -ip $ip -port $port -command "bosh -v" -usePrivateKey
        LogMsg "UPDATED bosh cli version: $out"
    }

    if($global:RunnerMode -eq "OnDemand" -and $env:BoshCLIVersion -eq "latest")
    {
        LogMsg "OnDemand mode, but request to update bosh cli to the latest"
		RunLinuxCmd -username $user -password $password -ip $ip -port $port -command "sudo gem install bosh_cli --no-ri --no-rdoc" -usePrivateKey
        $out = RunLinuxCmd -username $user -password $password -ip $ip -port $port -command "bosh -v" -usePrivateKey
        LogMsg "UPDATED bosh cli version: $out"
    }
	
    LogMsg "Executing : create-sql-rg.sh"
    RunLinuxCmd -username $user -password $password -ip $ip -port $port -command "sudo chmod +x *" -usePrivateKey
	RunLinuxCmd -username $user -password $password -ip $ip -port $port -command "sudo sh create-sql-rg.sh > create-sql-rg.log 2>&1" -runMaxAllowedTime 1200 -usePrivateKey
    
    RemoteCopy -download -downloadFrom $ip -files "/home/$user/meta-azure-service-broker/lib/broker/db/sqlserver/schema.sql" -downloadTo .\ -port $port -username $user -password $password -usePrivateKey
    LogMsg "Run a SQL command to create tables"
    $SQLfile ="$PWD\schema.sql"
    $connectionString = "Server=tcp:$sqlServerName.database.windows.net,1433;Initial Catalog=mySampleDatabase;Persist Security Info=False;User ID=ServerAdmin;Password=p@ssw0rdUser@123;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
    $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection($connectionString)
    $query = [IO.File]::ReadAllText($sqlFile)
    $command = New-Object -TypeName System.Data.SqlClient.SqlCommand($query, $connection)
    $connection.Open()
    $command.ExecuteNonQuery()
    $connection.Close()

    RemoteCopy -download -downloadFrom $ip -files "/home/$user/meta-azure-service-broker/manifest.yml" -downloadTo .\ -port $port -username $user -password $password -usePrivateKey
    $file = ".\manifest.yml"
    LogMsg "Update manifest file $file"
    $contents = Get-Content $file -raw
    $contents -replace 'ENVIRONMENT: REPLACE-ME', "ENVIRONMENT: $environment"`
          -replace 'SUBSCRIPTION_ID: REPLACE-ME', "SUBSCRIPTION_ID: $subscriptionID"`
          -replace "TENANT_ID: REPLACE-ME", "TENANT_ID: $spTenantID"`
          -replace 'CLIENT_ID: REPLACE-ME', "CLIENT_ID: $spClientID"`
          -replace 'CLIENT_SECRET: REPLACE-ME', "CLIENT_SECRET: $spClientSecret"`
          -replace 'SECURITY_USER_NAME: REPLACE-ME', "SECURITY_USER_NAME: $env:LinuxSudoUser"`
          -replace 'SECURITY_USER_PASSWORD: REPLACE-ME', "SECURITY_USER_PASSWORD: $env:LinuxSudoPwd"`
          -replace 'AZURE_BROKER_DATABASE_PROVIDER: REPLACE-ME', "AZURE_BROKER_DATABASE_PROVIDER: sqlserver"`
          -replace 'AZURE_BROKER_DATABASE_SERVER: REPLACE-ME', "AZURE_BROKER_DATABASE_SERVER: $sqlServerName.database.windows.net"`
          -replace 'AZURE_BROKER_DATABASE_USER: REPLACE-ME', "AZURE_BROKER_DATABASE_USER: ServerAdmin"`
          -replace 'AZURE_BROKER_DATABASE_PASSWORD: REPLACE-ME', "AZURE_BROKER_DATABASE_PASSWORD: p@ssw0rdUser@123"`
          -replace 'AZURE_BROKER_DATABASE_NAME: REPLACE-ME', "AZURE_BROKER_DATABASE_NAME: mySampleDatabase"`
          -replace 'AZURE_BROKER_DATABASE_ENCRYPTION_KEY: REPLACE-ME', "AZURE_BROKER_DATABASE_ENCRYPTION_KEY: abcdefghijklmnopqrstuvwxyz123456"`
          -replace "AZURE_SQLDB_ALLOW_TO_CREATE_SQL_SERVER: true \| false", "AZURE_SQLDB_ALLOW_TO_CREATE_SQL_SERVER: true"`
          -replace '"resourceGroup": "REPLACE-ME"', """resourceGroup"":""$resourceGroupName"""`
          -replace '"location": "REPLACE-ME"', """location"":""$locationofdatabase"""`
          -replace '"sqlServerName": "REPLACE-ME"', """sqlServerName"":""$sqlServerName"""`
          -replace '"administratorLogin": "REPLACE-ME"', '"administratorLogin":"ServerAdmin"'`
          -replace '"administratorLoginPassword": "REPLACE-ME"', '"administratorLoginPassword":"p@ssw0rdUser@123"' | out-file $file -Encoding default
    
    RemoteCopy -uploadTo $ip -port $port -files $file -username $user -password $password -upload -usePrivateKey -doNotCompress
    RunLinuxCmd -username $user -password $password -ip $ip -port $port -command "sudo cp /home/$user/manifest.yml /home/$user/meta-azure-service-broker/manifest.yml" -usePrivateKey

    LogMsg "Executing : $($currentTestData.testScript)"
	RunLinuxCmd -username $user -password $password -ip $ip -port $port -command "python $($currentTestData.testScript)" -runMaxAllowedTime 36000 -usePrivateKey
	RunLinuxCmd -username $user -password $password -ip $ip -port $port -command "mv Runtime.log $($currentTestData.testScript).log" -usePrivateKey
	RemoteCopy -download -downloadFrom $ip -files "/home/$user/deployCF.log, /home/$user/state.txt, /home/$user/Summary.log, /home/$user/$($currentTestData.testScript).log" -downloadTo $LogDir -port $port -username $user -password $password -usePrivateKey
	$testResult = Get-Content $LogDir\Summary.log
	$testStatus = Get-Content $LogDir\state.txt
	LogMsg "Test result : $testResult"

	if ($testStatus -eq "TestCompleted")
	{
		LogMsg "Test Completed"
	}
}
catch
{
    $info = $_.InvocationInfo
    "Line{0}, Col{1}, caught exception:{2}" -f $info.ScriptLineNumber,$info.OffsetInLine ,$_.Exception.Message
}
Finally
{
    if (!$testResult)
    {
        $testResult = "Aborted"
    }
	$resultArr += $testResult
}

$result = GetFinalResultHeader -resultarr $resultArr
#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed[1] -ResourceGroups $isDeployed[1]

#Return the result and summery to the test suite script..
return $result
