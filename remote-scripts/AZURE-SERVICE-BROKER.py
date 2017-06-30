#!/usr/bin/python

from azuremodules import *
import random, string, time

def generate_storage_config_jsonfile():
    resource_group_name = 'testrg-' + ''.join(random.choice(string.ascii_uppercase + string.ascii_lowercase + string.digits) for i in range(random.randint(3,83)))
    storage_account_name = ''.join(random.choice(string.ascii_lowercase + string.digits) for i in range(random.randint(3,24)))
    locations = Run('az account list-locations --query [].name')
    locations = json.loads(locations)
    location_name = random.choice(locations)
    account_types = ['Standard_LRS', 'Standard_ZRS', 'Standard_GRS', 'Standard_RAGRS', 'Premium_LRS']
    account_type = random.choice(account_types)
    file_name = 'storage-example-config.json'
    f = open(file_name, 'w')
    data = {}
    data["resource_group_name"] =  resource_group_name
    data["storage_account_name"] = storage_account_name
    data["location"] = location_name
    data["account_type"] = account_type
    json.dump(data, f, indent=4)
    f.close()
    return resource_group_name, storage_account_name

def generate_rediscache_config_jsonfile():
    resource_group_name = 'testrg-' + ''.join(random.choice(string.ascii_uppercase + string.ascii_lowercase + string.digits) for i in range(random.randint(3,83)))
    cache_name = ''.join(random.choice(string.ascii_lowercase + string.digits) for i in range(random.randint(3,63)))
    locations = Run('az account list-locations --query [].name')
    locations = json.loads(locations)
    location_name = random.choice(locations)
    enable_NonSslPort = random.choice([True, False])
    skus = ['Basic', 'Standard', 'Premium']
    sku = random.choice(skus)
    family = 'C'
    if sku == 'Premium':
        family = 'P'
    file_name = 'rediscache-example-config.json'
    f = open(file_name, 'w')
    data = {"resourceGroup": resource_group_name, "cacheName":cache_name, "parameters": {'location':location_name, 'enableNonSslPort': enable_NonSslPort, 'sku': {'name':sku,'family':family, 'capacity':0}}}
    json.dump(data, f, indent=4)
    f.close()

def generate_documentdb_config_jsonfile():
    resource_group_name = 'testrg-' + ''.join(random.choice(string.ascii_uppercase + string.ascii_lowercase + string.digits) for i in range(random.randint(3,83)))
    doc_db_account_name = ''.join(random.choice(string.ascii_lowercase + string.digits) for i in range(random.randint(3,50)))
    doc_db_name = ''.join(random.choice(string.ascii_lowercase + string.digits) for i in range(random.randint(3,50)))
    locations = Run('az account list-locations --query [].name')
    locations = json.loads(locations)
    location_name = random.choice(locations)
    file_name = 'documentdb-example-config.json'
    f = open(file_name, 'w')
    data = {"resourceGroup": resource_group_name, "docDbAccountName":doc_db_account_name, "docDbName":doc_db_name, "location":location_name } 
    json.dump(data, f, indent=4)
    f.close()

def generate_servicebus_config_jsonfile():
    resource_group_name = 'testrg-' + ''.join(random.choice(string.ascii_uppercase + string.ascii_lowercase + string.digits) for i in range(random.randint(3,83)))
    namespace_name = ''.join(random.choice(string.ascii_lowercase) for i in range(random.randint(6,50)))
    types = ['Messaging', 'EventHub', 'NotificationHub']
    type_value = random.choice(types)
    type_value = 'Messaging'
    if type_value=='Messaging':
        messaging_tier=random.choice(['Basic','Standard','Premium'])
    elif type_value=='EventHu':
        messaging_tier=random.choice(['Basic','Standard'])
    else:
        messaging_tier='Standard'
    locations = Run('az account list-locations --query [].name')
    locations = json.loads(locations)
    location_name = random.choice(locations)
    file_name = 'servicebus-example-config.json'
    f = open(file_name, 'w')
    data = {"resource_group_name": resource_group_name, "namespace_name":namespace_name, "type":type_value, "location":location_name, "messaging_tier":messaging_tier } 
    json.dump(data, f, indent=4)
    f.close()

def generate_sqldatabase_config_jsonfile():
    resource_group_name = 'testrg-' + ''.join(random.choice(string.ascii_uppercase + string.ascii_lowercase + string.digits) for i in range(random.randint(3,83)))
    sql_server_name = ''.join(random.choice(string.ascii_lowercase) for i in range(random.randint(6,63)))
    sql_db_name = ''.join(random.choice(string.ascii_lowercase) for i in range(random.randint(6,128)))
    locations = Run('az account list-locations --query [].name')
    locations = json.loads(locations)
    location_name = random.choice(locations)
    transparent_DataEncryption = random.choice([True, False])
    file_name = 'sqldb-example-config.json'
    f = open(file_name, 'w')
    data =  { \
            "resourceGroup": resource_group_name, "location":location_name,  \
            "sqlServerName":sql_server_name, "sqldbName":sql_db_name, "transparentDataEncryption": transparent_DataEncryption, \
            "sqldbParameters": {"properties": {"collation": "SQL_Latin1_General_CP1_CI_AS" }}, \
            "sqlServerParameters": { "allowSqlServerFirewallRules": [{"ruleName": "rule-01", "startIpAddress": "0.0.0.0", "endIpAddress": "255.255.255.255"}], \
                                   "properties": {"administratorLogin": "ServerAdmin",  "administratorLoginPassword": "p@ssw0rdUser@123"} } \
            } 
    json.dump(data, f, indent=4)
    f.close()

def generate_mysql_config_jsonfile():
    resource_group_name = 'testrg-' + ''.join(random.choice(string.ascii_uppercase + string.ascii_lowercase + string.digits) for i in range(random.randint(3,83)))
    mysql_server_name = ''.join(random.choice(string.ascii_lowercase) for i in range(random.randint(6,63)))
    locations = ["westus", "northeurope"]
    location_name = random.choice(locations)
    versions = ["5.6","5.7"]
    version =  random.choice(versions)
    sslEnable = random.choice(["Enabled", "Disabled"])
    file_name = 'mysqldb-example-config.json'
    f = open(file_name, 'w')
    data =  { \
            "resourceGroup": resource_group_name, "location":location_name, "mysqlServerName":mysql_server_name,\
            "mysqlServerParameters": { "allowMysqlServerFirewallRules": [{"ruleName": "rule-01", "startIpAddress": "0.0.0.0", "endIpAddress": "255.255.255.255"}], \
            "properties": {"version": version, "sslEnforcement":sslEnable, "storageMB": 51200, "administratorLogin": "ServerAdmin",  "administratorLoginPassword": "p@ssw0rdUser@123"}} \
            } 
    json.dump(data, f, indent=4)
    f.close()

def generate_postgresql_config_jsonfile():
    resource_group_name = 'testrg-' + ''.join(random.choice(string.ascii_uppercase + string.ascii_lowercase + string.digits) for i in range(random.randint(3,83)))
    postgresql_server_name = ''.join(random.choice(string.ascii_lowercase) for i in range(random.randint(6,63)))
    locations = ["westus", "northeurope"]
    location_name = random.choice(locations)
    versions = ["9.5","9.6"]
    version =  random.choice(versions)
    sslEnable = random.choice(["Enabled", "Disabled"])
    file_name = 'postgresqldb-example-config.json'
    f = open(file_name, 'w')
    data =  { \
            "resourceGroup": resource_group_name, "location":location_name, "postgresqlServerName":postgresql_server_name,\
            "postgresqlServerParameters": { "allowPostgresqlServerFirewallRules": [{"ruleName": "rule-01", "startIpAddress": "0.0.0.0", "endIpAddress": "255.255.255.255"}], \
            "properties": {"version": version, "sslEnforcement":sslEnable, "storageMB": 51200, "administratorLogin": "ServerAdmin",  "administratorLoginPassword": "p@ssw0rdUser@123"}} \
            } 
    json.dump(data, f, indent=4)
    f.close()

def generate_cosmosdb_config_jsonfile():
    resource_group_name = 'testrg-' + ''.join(random.choice(string.ascii_uppercase + string.ascii_lowercase + string.digits) for i in range(random.randint(3,83)))
    cosmosDb_account_Name = ''.join(random.choice(string.ascii_lowercase) for i in range(random.randint(3,31)))
    cosmosDb_Name = ''.join(random.choice(string.ascii_lowercase) for i in range(random.randint(3,50)))
    locations = Run('az account list-locations --query [].name')
    locations = json.loads(locations)
    location_name = random.choice(locations)
    kinds = ["DocumentDB", "Graph", "Table", "MongoDB"]
    kind =  random.choice(kinds)
    file_name = 'cosmosdb-example-config.json'
    f = open(file_name, 'w')
    data = {"resourceGroup": resource_group_name, "cosmosDbAccountName":cosmosDb_account_Name, "cosmosDbName":cosmosDb_Name,  "location":location_name, "kind":kind } 
    json.dump(data, f, indent=4)
    f.close()

def EnableService():
    Run('cf enable-service-access azure-storage')
    Run('cf enable-service-access azure-rediscache')
    Run('cf enable-service-access azure-documentdb')
    Run('cf enable-service-access azure-servicebus')
    Run('cf enable-service-access azure-sqldb')
    Run('cf enable-service-access azure-mysqldb')
    Run('cf enable-service-access azure-postgresqldb')
    Run('cf enable-service-access azure-cosmosdb')

def GenerateConfigJsonFiles():
    generate_storage_config_jsonfile()
    generate_rediscache_config_jsonfile()
    generate_documentdb_config_jsonfile()
    generate_servicebus_config_jsonfile()
    generate_sqldatabase_config_jsonfile()
    generate_mysql_config_jsonfile()
    generate_postgresql_config_jsonfile()
    generate_cosmosdb_config_jsonfile()

def CreateService():
    Run('cf create-service azure-storage standard mystorageservice -c storage-example-config.json')
    Run('cf create-service azure-rediscache basic myrediscache -c  rediscache-example-config.json')
    Run('cf create-service azure-documentdb standard mydocdb -c documentdb-example-config.json')
    Run('cf create-service azure-servicebus standard myservicebus -c servicebus-example-config.json')
    Run('cf create-service azure-sqldb basic mysqldatabase -c sqldb-example-config.json')
    Run('cf create-service azure-mysqldb basic100 mysqldb -c mysqldb-example-config.json')
    Run('cf create-service azure-postgresqldb basic100 postgresqldb -c postgresqldb-example-config.json')
    Run('cf create-service azure-cosmosdb standard mycosmosdb -c cosmosdb-example-config.json')

def CheckCreateServiceStatus():
    output = Run('cf service mystorageservice | grep -i Status')
    while not ('succeeded' in output.split(':')[1]):
        time.sleep(5)
        output = Run('cf service mystorageservice | grep -i Status')

    output = Run('cf service myrediscache | grep -i Status')
    while not ('succeeded' in output.split(':')[1]):
        time.sleep(5)
        output = Run('cf service myrediscache | grep -i Status')

    output = Run('cf service mydocdb | grep -i Status')
    while not ('succeeded' in output.split(':')[1]):
        time.sleep(5)
        output = Run('cf service mydocdb | grep -i Status')

    output = Run('cf service myservicebus | grep -i Status')
    while not ('succeeded' in output.split(':')[1]):
        time.sleep(5)
        output = Run('cf service myservicebus | grep -i Status')

    output = Run('cf service mysqldatabase | grep -i Status')
    while not ('succeeded' in output.split(':')[1]):
        time.sleep(5)
        output = Run('cf service mysqldatabase | grep -i Status')

    output = Run('cf service mysqldb | grep -i Status')
    while not ('succeeded' in output.split(':')[1]):
        time.sleep(5)
        output = Run('cf service mysqldb | grep -i Status')

    output = Run('cf service postgresqldb | grep -i Status')
    while not ('succeeded' in output.split(':')[1]):
        time.sleep(5)
        output = Run('cf service postgresqldb | grep -i Status')
        
    output = Run('cf service mycosmosdb | grep -i Status')
    while not ('succeeded' in output.split(':')[1]):
        time.sleep(5)
        output = Run('cf service mycosmosdb | grep -i Status')
    
def DeleteService():
    Run('cf delete-service mystorageservice -f')
    Run('cf delete-service myrediscache -f')
    Run('cf delete-service mydocdb -f')
    Run('cf delete-service myservicebus -f')
    Run('cf delete-service mysqldatabase -f')
    Run('cf delete-service mysqldb -f')
    Run('cf delete-service postgresqldb -f')
    Run('cf delete-service mycosmosdb -f')

def CheckDeleteServiceStatus():
    output = Run('cf service mystorageservice')
    while not ('not found' in output):
        time.sleep(5)
        output = Run('cf service mystorageservice')
    output = Run('cf service myrediscache')
    while not ('not found' in output):
        time.sleep(5)
        output = Run('cf service myrediscache')
    output = Run('cf service mydocdb')
    while not ('not found' in output):
        time.sleep(5)
        output = Run('cf service mydocdb')
    output = Run('cf service myservicebus')
    while not ('not found' in output):
        time.sleep(5)
        output = Run('cf service myservicebus')
    output = Run('cf service mysqldatabase')
    while not ('not found' in output):
        time.sleep(5)
        output = Run('cf service mysqldatabase')
    output = Run('cf service mysqldb')
    while not ('not found' in output):
        time.sleep(5)
        output = Run('cf service mysqldb')
    output = Run('cf service postgresqldb')
    while not ('not found' in output):
        time.sleep(5)
        output = Run('cf service postgresqldb')
    output = Run('cf service mycosmosdb')
    while not ('not found' in output):
        time.sleep(5)
        output = Run('cf service mycosmosdb')

def DeleteResourceGroup():
    output = Run('cat storage-example-config.json  | grep -i resource_group_name')
    Run('az group delete -n %s --yes --no-wait' % output.split(':')[1].split('"')[1])
    output = Run('cat rediscache-example-config.json  | grep -i resourceGroup')
    Run('az group delete -n %s --yes --no-wait' % output.split(':')[1].split('"')[1])
    output = Run('cat documentdb-example-config.json  | grep -i resourceGroup')
    Run('az group delete -n %s --yes --no-wait' % output.split(':')[1].split('"')[1])
    output = Run('cat servicebus-example-config.json  | grep -i resource_group_name')
    Run('az group delete -n %s --yes --no-wait' % output.split(':')[1].split('"')[1])
    output = Run('cat sqldb-example-config.json  | grep -i resourceGroup')
    Run('az group delete -n %s --yes --no-wait' % output.split(':')[1].split('"')[1])
    output = Run('cat postgresqldb-example-config.json  | grep -i resourceGroup')
    Run('az group delete -n %s --yes --no-wait' % output.split(':')[1].split('"')[1])
    output = Run('cat mysqldb-example-config.json  | grep -i resourceGroup')
    Run('az group delete -n %s --yes --no-wait' % output.split(':')[1].split('"')[1])
    output = Run('cat cosmosdb-example-config.json  | grep -i resourceGroup')
    Run('az group delete -n %s --yes --no-wait' % output.split(':')[1].split('"')[1])


def RunTest():
    UpdateState("TestStarted")
    RunLog.info('install azure-cli 2.0 and set azure subscription')
    InstallAzureCli()
    Run('sudo chown -R azureuser:azureuser /home/azureuser')
    set_azure_subscription('settings')
    if DeployCF(source_manifest_name):
        Run('wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | sudo apt-key add -') 
        Run('echo "deb http://packages.cloudfoundry.org/debian stable main" | sudo tee /etc/apt/sources.list.d/cloudfoundry-cli.list')
        Run("sudo apt-get update")
        Run("sudo apt-get install -y cf-cli")
        output = Run("cat settings | grep cf-ip")
        cf_ip =  output.split(':')[1].split('"')[1]
        RunLog.info('cf login')
        Run("cf login -a https://api.%s.xip.io --skip-ssl-validation -u admin -p c1oudc0w" % cf_ip)
        RunLog.info('cf create org')
        Run("cf create-org %s.xip.io_ORGANIZATION" % cf_ip)
        RunLog.info('cf create space')
        Run("cf create-space azure -o %s.xip.io_ORGANIZATION" % cf_ip)
        RunLog.info('cf target space and org')
        Run("cf target -o %s.xip.io_ORGANIZATION -s azure" % cf_ip)
        
        RunLog.info('cf target space and org')
        ExecMultiCmdsLocalSudo(["cd meta-azure-service-broker", "sudo npm install", "export NODE_ENV=production", "cf push"])
        Run('cf create-service-broker demo-service-broker shostctest P@ssw0rd01 http://meta-azure-service-broker.%s.xip.io' % cf_ip)

        GenerateConfigJsonFiles()
        EnableService()
        CreateService()
        CheckCreateServiceStatus()
        #Download application
        #Bind application
        #test
        #Unbind application
        DeleteService()
        CheckDeleteServiceStatus()
        DeleteResourceGroup()

        #ResultLog.error('PASS')
        UpdateState("TestCompleted")
    else:
        ResultLog.error('FAIL')
        UpdateState("TestCompleted")

#set variable
source_manifest_name = 'example_manifests/multiple-vm-cf.yml'
RunTest()
