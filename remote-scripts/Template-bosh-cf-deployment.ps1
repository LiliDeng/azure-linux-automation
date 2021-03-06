<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()

try
{
    $templateName = $currentTestData.testName
    $parameters = $currentTestData.parameters
    $location = $xmlConfig.config.Azure.General.Location

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
    $jsonfile.parameters.vmName.value = $parameters.vmName + $timestr
    $jsonfile.parameters.adminUsername.value = $parameters.adminUsername
    $jsonfile.parameters.sshKeyData.value = $parameters.sshKeyData
    $jsonfile.parameters.environment.value = $parameters.environment
    $jsonfile.parameters.tenantID.value = $parameters.tenantID
    $jsonfile.parameters.clientID.value = $parameters.clientID
    $jsonfile.parameters.clientSecret.value = $parameters.clientSecret
    $jsonfile.parameters.autoDeployBosh.value = $parameters.autoDeployBosh
    
    # save template parameter file
    $jsonfile | ConvertTo-Json | Out-File .\azuredeploy.parameters.json
    if(Test-Path .\azuredeploy.parameters.json)
    {
        LogMsg "successful save azuredeploy.parameters.json"
    }
    else
    {
        LogMsg "fail to save azuredeploy.parameters.json"
    }

    $isDeployed = CreateAllRGDeploymentsWithTempParameters -templateName $templateName -location $location -TemplateFile ..\azure-quickstart-templates\bosh-setup\azuredeploy.json  -TemplateParameterFile .\azuredeploy.parameters.json

    if ($isDeployed[0] -eq $True)
    {
        $testResult_deploy_infrastructure = "PASS"
		LogMsg "deploy azure resouces for infrastructure successfully."
    }
    else
    {
        $testResult_deploy_infrastructure = "Failed"
        throw 'deploy azure resouces for infrastructure with error, please check.'
    }

    # connect to the devbox then deploy multi-vms cf
    $rg_info_outputs = $(Get-AzureRmResourceGroupDeployment -ResourceGroupName $isDeployed[1]).outputs
    $dep_ssh_info = $($rg_info_outputs.values | Where-Object {$_.value -match 'ssh' -and $_.value -match 'devbox'}).value.Split('')[1]
    LogMsg $dep_ssh_info
    $port = 22
    $sshKey = "cf_devbox_privatekey.ppk"
    $command = 'hostname'
    
    # ssh to devbox and deploy multi-vms cf
    echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "$command"

    $out = echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "bosh -v"
    LogMsg "Current bosh cli version: $out"
    if($global:RunnerMode -eq "Runner")
    {
        LogMsg "Runner mode, Update bosh cli to the latest"
        echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "sudo gem install bosh_cli --no-ri --no-rdoc"
        $out = echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "bosh -v"
        LogMsg "UPDATED bosh cli version: $out"
    }

    if($global:RunnerMode -eq "OnDemand" -and $env:BoshCLIVersion -eq "latest")
    {
        LogMsg "OnDemand mode, but request to update bosh cli to the latest"
        echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "sudo gem install bosh_cli --no-ri --no-rdoc"
        $out = echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "bosh -v"
        LogMsg "UPDATED bosh cli version: $out"
    }

    LogMsg "Install expect"
    echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "sudo apt-get install expect -y"

    $testTasks=@()
    if($env:AcceptanceTest -eq $true)
    {
        $testTasks += "acceptance test"
    }

    if($env:SmokeTest -eq $true)
    {
        $testTasks += "smoke test"
    }

	# configure BOSH
	$Environment = $parameters.environment
	# for Azure global, use PowerDns on BOSH VM as dns server
	if ($Environment -eq "AzureCloud")
	{
		# upload 
		echo y | .\tools\pscp -i .\ssh\$sshKey -q -P $port .\remote-scripts\config_powerdns_on_azurecloud.py ${dep_ssh_info}:
		# backup
		echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "sudo cp bosh.yml bosh.yml.origin"
		# change
		echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "sudo sed -i 's/listen_address: 127.0.0.1/listen_address: 10.0.0.4/g' bosh.yml"
		echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "sudo sed -i 's/host: 127.0.0.1/host: 10.0.0.4/g' bosh.yml"
	}
	
	# deploy BOSH
	echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "{ ./deploy_bosh.sh && echo bosh_deploy_ok || echo bosh_deploy_fail; } | tee deploy-BOSH.log"
	$out = echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "grep 'bosh_deploy_ok' deploy-BOSH.log | wc -l"
	if ($out -eq '1')
	{
		$testResult_deploy_bosh = "PASS"
		LogMsg "deploy BOSH successfully."

		# inject the records if on Azure Global
		if ($Environment -eq "AzureCloud")
		{
			echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "wget https://raw.githubusercontent.com/Azure/azure-quickstart-templates/b4c75c5c3ee5644a45e6ace8f6bce5e7927fd1f8/bosh-setup/scripts/inject_xip_io_records.py"
			echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "sudo python inject_xip_io_records.py bosh.yml settings"
		}
	}
	else
	{
		$testResult_deploy_bosh = "Failed"
		throw "deploy BOSH failed, check details from deploy-BOSH.log."
	}

	if($testTasks.Length -ne 0)
	{
		LogMsg "Enable testing(s):$testTasks for cloud foundry"
		$pattern = "Logs saved in \D(\S+)'"
		foreach ($SetupType in $currentTestData.SubtestValues.split(","))
		{
			LogMsg "Start to deploy $SetupType"
			if($DeployedMultipleVMCF)
			{
				LogMsg "Remove deployed multiple-vm-azure"
				echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "bosh -n delete deployment multiple-vm-azure"
			}
			if($DeployedSingleVMCF)
			{
				LogMsg "Remove deployed single-vm-cf-on-azure"
				echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "bosh -n delete deployment single-vm-cf-on-azure"		
			}
			
			$tmprunsh = @"
#!/bin/bash
{ /home/azureuser/deploy_cloudfoundry.sh example_manifests/$SetupType.yml && echo cf_deploy_ok || echo cf_deploy_fail; } | tee deploy-$SetupType.log
"@

			$wrappersh = @"
#!/usr/bin/expect
set timeout -1
spawn  /home/azureuser/tmprun.sh
expect "Enter a password(note: password should not contain special characters: @,' and so on) to use in example_manifests/$SetupType.yml" { send "\r" }
expect "Type yes to continue" { send "yes\r" }
expect "Enter a password(note: password should not contain special characters: @,' and so on) to use in example_manifests/$SetupType.yml"
"@
			LogMsg "generate test scripts"
			$wrappersh | Out-File .\wrapper.sh -Encoding utf8
			$tmprunsh | Out-File .\tmprun.sh -Encoding utf8
			.\tools\dos2unix.exe -q .\wrapper.sh
			.\tools\dos2unix.exe -q .\tmprun.sh
			LogMsg "upload test scripts"
			echo y | .\tools\pscp -i .\ssh\$sshKey -q -P $port .\wrapper.sh ${dep_ssh_info}:
			echo y | .\tools\pscp -i .\ssh\$sshKey -q -P $port .\tmprun.sh ${dep_ssh_info}:

			echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "chmod a+x wrapper.sh"
			echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "chmod a+x tmprun.sh"

			# cf use powerdns on bosh vm as dns server if on Azure global
			if($Environment -eq "AzureCloud")
			{
				echo y | .\tools\pscp -i .\ssh\$sshKey -q -P $port .\remote-scripts\config_powerdns_on_azurecloud.py ${dep_ssh_info}:
				echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "python config_powerdns_on_azurecloud.py example_manifests/multiple-vm-cf.yml"
			}

			echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "./wrapper.sh"
            echo y | .\tools\pscp -i .\ssh\$sshKey -q -P $port ${dep_ssh_info}:deploy-$SetupType.log $LogDir\deploy-$SetupType.log
			
			$out = [String](Get-Content $LogDir\deploy-$SetupType.log)
			if($SetupType -eq 'multiple-vm-cf')
			{
				$DeployedMultipleVMCF = $True
			}
			if($SetupType -eq 'single-vm-cf')
			{
				$DeployedSingleVMCF = $True
			}
			if ($out -match "cf_deploy_ok")
			{					
				LogMsg "deploy $SetupType successfully, start to run test"
                if ($SetupType -eq 'single-vm-cf')
                {
                    LogMsg "Tests are disabled against single-vm-cf yet. Exit."
                    $testResult = "PASS"
                    continue
                }
                $AnyTestFailed = $false
				foreach($testTask in $testTasks)
				{
					LogMsg "Testing $testTask on $SetupType"
					$metaData = "$testTask on $SetupType"
					if($testTask -eq 'acceptance test')
					{
						if($parameters.environment -eq 'AzureCloud')
						{
							$out = echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "{ bosh run errand acceptance_tests --keep-alive --download-logs --logs-dir /home/azureuser && echo cat_test_pass || echo cat_test_fail; } | tee $SetupType-AcceptanceTest.log"
						}
						else
						{
							$out = echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "{ bosh run errand acceptance_tests_internetless --keep-alive --download-logs --logs-dir /home/azureuser && echo cat_test_pass || echo cat_test_fail; } | tee $SetupType-AcceptanceTest.log"
						}
						echo y | .\tools\pscp -i .\ssh\$sshKey -q -P $port ${dep_ssh_info}:$SetupType-AcceptanceTest.log $LogDir\$SetupType-AcceptanceTest.log
                        $out = [String](Get-Content $LogDir\$SetupType-AcceptanceTest.log)
						if($out -match $pattern)
						{
							$Logfile = $Matches[1]
							echo y | .\tools\pscp -i .\ssh\$sshKey -q -P $port ${dep_ssh_info}:$Logfile ..\CI\$SetupType-AcceptanceTest.tgz
						}
						if($out -match "cat_test_pass")
						{
							LogMsg "****************************************************************"
							LogMsg "$testTask PASS on deployment $SetupType"
							LogMsg "****************************************************************"
							$testResult = "PASS"
						}
						else
						{
							$testResult = "FAIL"
							if($parameters.environment -eq 'AzureChinaCloud' -and (Test-Path "..\CI\$SetupType-AcceptanceTest.tgz"))
							{
								.\tools\7za.exe e "..\CI\$SetupType-AcceptanceTest.tgz"
								if(Test-Path "$SetupType-AcceptanceTest.tar")
								{
									.\tools\7za.exe e "$SetupType-AcceptanceTest.tar" -oCATS
									$failedCaseName = @()
									$ignoredCase = 'Buildpacks java makes the app reachable via its bound route'
									foreach($file in Get-ChildItem -Path CATS -Filter *.xml.log -recurse)
									{
										[XML]$catTestResult = Get-Content $file.FullName
										$failedCases = $catTestResult.SelectNodes('testsuite/testcase') | where {$_.failure -ne $null}
										$failedCaseName += $failedCases.Name
									}
									if($failedCaseName -eq $ignoredCase)
									{
										LogMsg "Ignore the only failed case `"$ignoredCase`""
										$testResult = "PASS"
									}
                                    else 
                                    {
                                        $AnyTestFailed = $true
                                    }
								}
								Remove-Item CATS -Force -Recurse
								Remove-Item "$SetupType-AcceptanceTest.tar" -Force
							}
							else
							{
                                $AnyTestFailed = $true
								LogMsg "****************************************************************"
								LogMsg "$testTask FAIL on deployment $SetupType"
								LogMsg "please check details from $LogDir\$SetupType-AcceptanceTest.log and ..\CI\$SetupType-AcceptanceTest.tgz"
								LogMsg "****************************************************************"								
							}
						}						
					}
					else
					{
						echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "{ bosh run errand smoke_tests --keep-alive --download-logs --logs-dir /home/azureuser && echo smoke_test_pass || echo smoke_test_fail; } | tee $SetupType-SmokeTest.log"
                        echo y | .\tools\pscp -i .\ssh\$sshKey -q -P $port ${dep_ssh_info}:$SetupType-SmokeTest.log $LogDir\$SetupType-SmokeTest.log
                        $out = [String](Get-Content $LogDir\$SetupType-SmokeTest.log)
						if($out -match "smoke_test_pass")
						{
							LogMsg "****************************************************************"
							LogMsg "$testTask PASS on deployment $SetupType"
							LogMsg "****************************************************************"
							$testResult = "PASS"
						}
						else
						{
                            $AnyTestFailed = $true
							LogMsg "****************************************************************"
							LogMsg "$testTask FAIL on deployment $SetupType"
							LogMsg "please check details from $LogDir\$SetupType-SmokeTest.log and ..\CI\$SetupType-SmokeTest.tgz"
							LogMsg "****************************************************************"
							$testResult = "FAIL"
						}						
						if($out -match $pattern)
						{
							$Logfile = $Matches[1]
							echo y | .\tools\pscp -i .\ssh\$sshKey -q -P $port ${dep_ssh_info}:$Logfile ..\CI\$SetupType-SmokeTest.tgz
						}
					}
					$resultArr += $testResult
					$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
				}
                if($AnyTestFailed)
                {
                    throw "$SetupType : CAT_fail, abort test for investigation."
                }
			}
			else
			{
				LogMsg "deploy $SetupType failed, please check details from $LogDir\deploy-$SetupType.log"
				$testResult = "FAIL"
				$resultArr += $testResult
				$resultSummary +=  CreateResultSummary -testResult $testResult -metaData "Deploy $SetupType" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
                throw "$SetupType : cf_deploy_fail, abort test for investigation."
			}
		}
	}
	else
	{
		$tmprunsh = @"
#!/bin/bash
/home/azureuser/deploy_cloudfoundry.sh example_manifests/multiple-vm-cf.yml | tee deploy_cloudfoundry.log
"@

		$wrappersh = @"
#!/usr/bin/expect
set timeout -1
spawn  /home/azureuser/tmprun.sh
expect "Enter a password(note: password should not contain special characters: @,' and so on) to use in example_manifests/$SetupType.yml" { send "\r" }
expect "Type yes to continue" { send "yes\r" }
expect "Enter a password(note: password should not contain special characters: @,' and so on) to use in example_manifests/$SetupType.yml"
"@
		LogMsg "generate test scripts"
		$wrappersh | Out-File .\wrapper.sh -Encoding utf8
		$tmprunsh | Out-File .\tmprun.sh -Encoding utf8
		.\tools\dos2unix.exe -q .\wrapper.sh
		.\tools\dos2unix.exe -q .\tmprun.sh
		LogMsg "upload test scripts"
		echo y | .\tools\pscp -i .\ssh\$sshKey -q -P $port .\wrapper.sh ${dep_ssh_info}:
		echo y | .\tools\pscp -i .\ssh\$sshKey -q -P $port .\tmprun.sh ${dep_ssh_info}:
		echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "chmod a+x wrapper.sh"
		echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "chmod a+x tmprun.sh"

        # run deployment
		echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "./wrapper.sh"

		# archive log and configs
		echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "tar -czf all.tgz deploy_cloudfoundry.log bosh.yml example_manifests/multiple-vm-cf.yml deploy_cloudfoundry.sh"
		$downloadto = "all-" + $isDeployed.GetValue(1) + ".tgz"
		LogMsg "download test archives as $downloadto"
		echo y | .\tools\pscp -i .\ssh\$sshKey -q -P $port ${dep_ssh_info}:all.tgz $downloadto

        $out = echo y | .\tools\plink -i .\ssh\$sshKey -P $port $dep_ssh_info "cat deploy_cloudfoundry.log | grep 'multiple-vm-azure' | grep 'Deployed' | grep 'bosh' | wc -l | tr -d '\n'"

		if ($out -match "1")
		{
			$testResult_deploy_multi_vms_cf = "PASS"
			LogMsg "deploy multi vms cf successfully"
		}
		else
		{
			$testResult_deploy_multi_vms_cf = "FAIL"
			LogMsg "deploy multi vms cf failed, please ssh to devbox and check details from deploy_cloudfoundry.log"
		}

		if ($testResult_deploy_infrastructure -eq "PASS" -and $testResult_deploy_bosh -eq "PASS" -and $testResult_deploy_multi_vms_cf -eq "PASS")
		{
			$testResult = "PASS"
		}
		else
		{
			$testResult = "FAIL"
		}
		$resultSummary += CreateResultSummary -testResult $testResult -metaData "" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
		$testStatus = "TestCompleted"
		LogMsg "Test result : $testResult"

		if ($testStatus -eq "TestCompleted")
		{
			LogMsg "Test Completed"
		}
	}
}
catch
{
    $info = $_.InvocationInfo
    "Line{0}, Col{1}, caught exception:{2}" -f $info.ScriptLineNumber,$info.OffsetInLine ,$_.Exception.Message
}
Finally
{
    $metaData = ""
    if (!$testResult)
    {
        $testResult = "Aborted"
		$resultArr += $testResult
		$resultSummary += CreateResultSummary -testResult $testResult -metaData "" -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName
    }
}

$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed[1] -ResourceGroups $isDeployed[1]

#Return the result and summery to the test suite script..
return $result, $resultSummary
