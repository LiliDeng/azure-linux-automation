#!/usr/bin/python

from azuremodules import *
import random

def Update_cf_manifest(source_yml_file, destination_yml_file):
    RunLog.info("Update CF manifest file")
    out = load_manifest(source_yml_file)
    out['jobs'] = remove_unnessary_jobs(out)
    out['releases'] = remove_unnessary_releases(out)
    out['resource_pools'] = remove_unnessary_resourcepools(out)
    out['releases'][0]['version'] = 'latest'
    out['resource_pools'][0]['stemcell']['version'] = 'latest'
    network = filter(lambda j:j.get('name') == 'cf_private', out['networks'])
    network[0]['type'] = 'dynamic'
    network[0]['subnets'][0].pop('reserved')
    network[0]['subnets'][0].pop('static')
    network[0]['subnets'][0].pop('gateway')
    out['name'] = cf_deployment_name
    out['jobs'][0]['name'] = 'dynamicnet_z1'
    out['jobs'][0]['networks'][0].pop('static_ips')
    generate_manifest(destination_yml_file ,out)

def RunTest():
    UpdateState("TestStarted")
    RunLog.info('install azure-cli 2.0 and set azure subscription')
    InstallAzureCli()
    set_azure_subscription('settings')
    data = load_jsonfile('settings')
    resource_group_name = data['RESOURCE_GROUP_NAME']	
    Update_cf_manifest(source_manifest_name, destination_manifest_name)
    if DeployCF(destination_manifest_name):
        RunLog.info('Start to verify the private network type')
        host_name = Run("bosh vms --details | grep dynamicnet_z1 | awk '{print $13}'")
        network_info = Run('az network nic list -g %s --query "[?contains(to_string(ipConfigurations[].id),\'%s\')] | [].ipConfigurations"' % (resource_group_name, host_name.strip('\n')))
        data = json.loads(network_info)
        privateNetworkType = data[0][0]['privateIpAllocationMethod']
        RunLog.info('Actually the private network type is : %s, expected value is Dynamic' % privateNetworkType)
        if privateNetworkType == 'Dynamic':
            RunLog.info("Test PASS, Remove deployed CF %s and test resources" % cf_deployment_name)
            Run("echo yes | bosh delete deployment %s" % cf_deployment_name)
            ResultLog.info('PASS')
        else:
            RunLog.info("Test FAIL")
            ResultLog.info('FAIL')
    else:
        ResultLog.error('FAIL')
    UpdateState("TestCompleted")


#set variable
source_manifest_name = 'example_manifests/single-vm-cf.yml'
destination_manifest_name = 'cpi-dynamic-network-cf.yml'
cf_deployment_name = 'dynamic-network-cf'

RunTest()
