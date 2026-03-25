#!/usr/bin/env python
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

import warnings
from cryptography.utils import CryptographyDeprecationWarning
warnings.filterwarnings("ignore", category=CryptographyDeprecationWarning)

import logging
import requests
import paramiko
import socket
import argparse
import sys

__authors__ = ['Laraib Kazi', 'Tyler FitzGerald']
__version__ = '2.0.1'

logdir = '/var/log/vmware/vcf/'
logFile = logdir+'fixHostKeys.log'
logging.basicConfig( filename = logFile,filemode = 'a',level = logging.DEBUG,format = '%(asctime)s [%(levelname)s]: %(message)s', datefmt = '%m/%d/%Y %I:%M:%S %p' )
logger = logging.getLogger(__name__)

CYELLOW = '\033[93m'
CGREEN = '\033[92m'
CRED = '\033[91m'
CBLUE = '\033[96m'
CEND = '\033[0m'

CHECKMARK = '\u2713'
CROSS = '\u2717'

KNOWN_HOST_FILES = ['/root/.ssh/known_hosts',
                     '/etc/vmware/vcf/commonsvcs/known_hosts',
                     '/home/vcf/.ssh/known_hosts',
                     '/opt/vmware/vcf/commonsvcs/defaults/hosts/known_hosts']

# HOST_KEY_ALGOS = ['ssh-ed25519',
#                   'ecdsa-sha2-nistp256',
#                   'ecdsa-sha2-nistp384',
#                   'ecdsa-sha2-nistp521',
#                   'ssh-rsa']

HOST_KEY_ALGOS = ['ssh-ed25519',
                  'ecdsa-sha2-nistp256',
                  'ssh-rsa']


def title():
    head=f'''
  __ _      _   _           _   _   __               
 / _(_)    | | | |         | | | | / /               
| |_ ___  _| |_| | ___  ___| |_| |/ /  ___ _   _ ___ 
|  _| \ \/ /  _  |/ _ \/ __| __|    \ / _ \ | | / __|
| | | |>  <| | | | (_) \__ \ |_| |\  \  __/ |_| \__ \\
|_| |_/_/\_\_| |_/\___/|___/\__\_| \_/\___|\__, |___/
                                            __/ |    
                                           |___/     
=============================================================
                    {CBLUE}Version: {__version__}{CEND}

'''
    print(head)
    logger.info(f'-------------- Starting fixHostKeys version: {__version__} ------------------')

def getArgs():
    parser = argparse.ArgumentParser(description='Script to Fix Host Key mismatches across all known_hosts files in the SDDC Manager')
    group = parser.add_mutually_exclusive_group(required=True)
    
    group.add_argument('--resourceType', action='store', help='One of these Resource Types: VCENTER | NSX_T_MANAGER | ESXI | NSXT_EDGE')
    group.add_argument('--node', action='store', help='FQDN of the specific resource')

    ## TODO:
    ## Option to fix for all resources in a particular domain
    ## Scan-all
    
    args = parser.parse_args()
    return args

def domainSelector():
    # Getting Domain Info
    api_url = "http://localhost/inventory/domains"
    headers = {'Accept': 'application/json', 'Content-Type': 'application/json'}
    logger.info(f'Attempting GET API Call with URL {api_url}')
    response = requests.request("GET", api_url, headers=headers, verify=False)
    logger.debug(f'Found Domains:\n{(response.json())}')
    domains = response.json()

    print(f"\n{CBLUE}VCF Domains found:{CEND}")
    count = -1
    for element in domains:
        count = count + 1
        domainChoice = (f"[{str(count)}] {element['id']} | {element['name']} | {element['type']} | {element['status']}")
        print(domainChoice)
        logger.info(f'Domain Choice: {domainChoice}')

    print("")
    print("Select the Domain where resource exists:")
    while True:
        ans_file = input("Select Number: ")
        logger.info(f'Input Selection: {ans_file}')
        # If Selection is beyond the list displayed
        if int(ans_file) > count:
            logger.error(f"Invalid selection: {ans_file}")
            continue
        else:
            selection = int(ans_file)
            print(f"\nDomain selected is : {CBLUE}{domains[selection]['name']}{CEND} ") 
            logger.info(f"Domain selected is : {domains[selection]}")
            break
    
    return domains[selection]

def getDomainResources(domainId, resourceType): 
    
    # Getting vCenter Info
    if resourceType == 'vcenter':
        vcenter=[]
        api_url = f'http://localhost/inventory/vcenters'
        headers = {'Accept': 'application/json', 'Content-Type': 'application/json'}
        logger.info(f'Attempting GET API Call with URL {api_url}')
        response = requests.request("GET", api_url, headers=headers, verify=False)
        for element in response.json():
            if element['domainId'] == domainId: 
                logger.debug(f'Found VCENTER element : {element}')
                vcenter.append({'id':element['id'], 'fqdn':element['hostName'], 'ip':element['managementIpAddress']})
                break
        return vcenter
    
    # Getting NSXT Info
    if resourceType == 'nsx_t_manager':
        nsxtManagers=[]        
        api_url = f'http://localhost/inventory/nsxt'
        headers = {'Accept': 'application/json', 'Content-Type': 'application/json'}
        logger.info(f'Attempting GET API Call with URL {api_url}')
        response = requests.request("GET", api_url, headers=headers, verify=False)
        for element in response.json():
            if domainId in element['domainIds']:
                logger.debug(f'Found NSX element : {element}')
                for nsxt in element['nsxtClusterDetails']:
                    nsxtManagers.append({'id':nsxt['id'], 'fqdn':nsxt['fqdn'], 'ip':nsxt['ipAddress']})
                break
        return nsxtManagers

    # Getting Host Info
    if resourceType == 'esxi':
        host=[]
        api_url = f'http://localhost/inventory/hosts'
        headers = {'Accept': 'application/json', 'Content-Type': 'application/json'}
        logger.info(f'Attempting GET API Call with URL {api_url}')
        response = requests.request("GET", api_url, headers=headers, verify=False)
        for element in response.json():
            try:
                if element['domainId'] == domainId:
                    logger.debug(f'Found ESX element : {element}')
                    entry = {'fqdn': element['hostName']}
                    host.append(entry)  
            except Exception as e:
                logger.error(f'Host likely not part of a domain. Error: {e}')
        return host  
    
    # TODO:
    # Getting Edge Node Info    
    
def vrslcmInfo():
    """
    Gets vRSLCM Info from local inventory API

    Returns:
        string: Hostname of the vRSLCM Node
    """
    api_url = 'http://localhost/inventory/vrslcms'
    api_type = "GET"
    response = requests.request(api_type, api_url, verify=False)

    try:
        vrslcmResponse = response.json()[0]
        logger.debug(f'vRSLCM instance found: {vrslcmResponse}') 
        vrslcmHostname = vrslcmResponse['vrslcmNode']['hostName']
        return vrslcmHostname
    except Exception as e:
        logger.error(f'Failed to get vRSLCM instance in SDDC Manager. Exception: {e}')
        return None
    
def vropsInfo():
    """
    Gets vROPs Info from local inventory API

    Returns:
        dict: A dictionary containing the following information:
            - loadbalancer (string): Hostname of the Load Balancer for vROPS
            - masterHostname (string): Hostname of the vROPS Master Node
    """
    api_url = 'http://localhost/inventory/vrops'
    api_type = "GET"
    response = requests.request(api_type, api_url, verify=False)
    
    try:
        vropsResponse = response.json()[0]
        logger.debug(f'vROPS instance found: {vropsResponse}') 
        vropsLBHostname = vropsResponse['loadBalancerHostname']
        vropsMasterHostname = vropsResponse['masterNode']['hostName']
        return {'loadbalancer':vropsLBHostname, 'masterHostname':vropsMasterHostname}
    except Exception as e:
        logger.error(f'Failed to get vROPS instance in SDDC Manager. Exception: {e}')
        return None
    
def vrliInfo():
    """
    Gets vRLI Info from local inventory API

    Returns:
        dict: A dictionary containing the following information:
            - loadbalancer (string): Hostname of the Load Balancer for vRLI
            - masterHostname (string): Hostname of the vRLI Master Node
    """
    api_url = 'http://localhost/inventory/vrlis'
    api_type = "GET"
    response = requests.request(api_type, api_url, verify=False)
    
    try:
        vrliResponse = response.json()[0]
        logger.debug(f'vRLI instance found: {vrliResponse}') 
        vrliLBHostname = vrliResponse['loadBalancerHostname']
        vrliMasterHostname = vrliResponse['masterNode']['hostName']
        return {'loadbalancer':vrliLBHostname, 'masterHostname':vrliMasterHostname}
    except Exception as e:
        logger.error(f'Failed to get vRLI instance in SDDC Manager. Exception: {e}')
        return None
    
def vraInfo():
    """
    Gets vRA Info from local inventory API

    Returns:
        dict: A dictionary containing the following information:
            - loadbalancer (string): Hostname of the Load Balancer for vRA
            - nodes (list): List of dicts for the vRA nodes
    """
    api_url = 'http://localhost/inventory/vras'
    api_type = "GET"
    response = requests.request(api_type, api_url, verify=False)
    
    try:
        vraResponse = response.json()[0]
        logger.debug(f'vRA instance found: {vraResponse}') 
        vraLBHostname = vraResponse['cafeLbHostname']
        vraNodes = vraResponse['cafeNodes']
        return {'loadbalancer':vraLBHostname, 'nodes':vraNodes}
    except Exception as e:
        logger.error(f'Failed to get vRA instance in SDDC Manager. Exception: {e}')
        return None

def wsaInfo():
    """
    Gets Workspace One Access Info from local inventory API

    Returns:
        dict: A dictionary containing the following information:
            - loadbalancer (string): Hostname of the Load Balancer for WSA
            - primaryHostname (string): Hostname of the WSA Primary Node
    """
    api_url = 'http://localhost/inventory/wsas'
    api_type = "GET"
    response = requests.request(api_type, api_url, verify=False)
    
    try:
        wsaResponse = response.json()[0]
        logger.debug(f'WSA instance found: {wsaResponse}') 
        wsaLBHostname = wsaResponse['lbHostname']
        wsaPrimaryHostname = wsaResponse['primaryNode']['hostName']
        return {'loadbalancer':wsaLBHostname, 'primaryHostname':wsaPrimaryHostname}
    except Exception as e:
        logger.error(f'Failed to get WSA instance in SDDC Manager. Exception: {e}')
        return None

def sshStatusCheck(host):
    address = host+':22' # Using the default SSH port
    try:
        transport = paramiko.Transport(address)
        return True
    except paramiko.ssh_exception.SSHException as e:
        return False

def connect_and_update(host, algo, file):
    
    address = host+':22' # Using the default SSH port
    transport = paramiko.Transport(address)
    
    transport.get_security_options().key_types = [algo]
    transport.connect()
    key = transport.get_remote_server_key()
    logger.info(f' > Found Key {key.get_name()} for {host}: {key.get_base64()}')
    transport.close()

    hostfile = paramiko.HostKeys(filename=file)
    hostfile.add(hostname = host, key=key, keytype=key.get_name())
    hostfile.save(filename=file)
    
    return key.get_name()

def update_known_host_files(host):
    logger.debug(f"Adding entries from known_hosts files for {host} ...")
    keynames = []
    for file in KNOWN_HOST_FILES:
        for algo in HOST_KEY_ALGOS:
            try:
                keynames.append(connect_and_update(host, algo, file))
            except Exception as e:
                #print()
                logger.error(f'Error for {host} with algo: {algo} : {e}')
    return keynames
    
def deleteExistingHostKeys(host):
    logger.debug(f"Deleting entries from known_hosts files for {host} ...")
    for file in KNOWN_HOST_FILES:
        new_lines = []
        with open(file, "r") as openFile:
            entireFile = openFile.read()
            # Update line-by-line ONLY if entry exists:
            if host in entireFile:
                openFile.seek(0)
                lines = openFile.readlines()
                for line in lines:
                    if host not in line:
                        new_lines.append(line)
                
        if new_lines:
            with open(file, "w") as openFile:
                openFile.writelines(new_lines)

def apiRefresh():
    api_url = f'http://localhost/appliancemanager/ssh/knownHosts/refresh'
    headers = {'Accept': 'application/json', 'Content-Type': 'application/json'}
    logger.info(f'Attempting PUSH API Call with URL {api_url}')
    response = requests.request("PUSH", api_url, headers=headers, verify=False)
    
def updateEverything(nodeFqdn):
    
    print(f"\n  >> Updating Host Keys for Node: {CBLUE}{nodeFqdn}{CEND}",end='')
    isSSHEnabled = sshStatusCheck(nodeFqdn)
    if isSSHEnabled is True:
        try:
            nodeIp = socket.gethostbyname(nodeFqdn)
        except:
            print(f'!! Failed to resolve IP address for {nodeFqdn}')
        
        # Clean up entries with fqdn:
        deleteExistingHostKeys(nodeFqdn)
        # Clean up entries with ip:
        if nodeIp:
            deleteExistingHostKeys(nodeIp)
        
        # Add entries with fqdn:
        keynames = update_known_host_files(nodeFqdn)
        # Add entries with ip:
        if nodeIp:
            update_known_host_files(nodeIp)
        
        keys=''
        # Get unique host key types
        uniqueKeyNames = set(keynames)
        keynames = list(uniqueKeyNames)
        for key_name in keynames:
            keys+=key_name+"  "
        print(f" | [{CGREEN}{CHECKMARK}{CEND}] Updated host keys of type: {CGREEN}{keys}{CEND}")
        
    else:
        print(f" | [{CRED}{CROSS}{CEND}] {CRED}SSH is disabled for {nodeFqdn}{CEND}")
    
    
def main():

    args = getArgs()
      
    if args.node:
        
        updateEverything(args.node)
    
    elif args.resourceType:
        
        resourceType = args.resourceType.lower()
        if resourceType in ['vcenter', 'nsx_t_manager', 'esxi', 'nsxt_edge']:
            domainSelection = domainSelector()
            domainNodes = getDomainResources(domainSelection['id'], resourceType)

            ans = input(f"\n Attempting to update Host Keys for all {CBLUE}{args.resourceType}{CEND} nodes in domain: {CBLUE}{domainSelection['name']}{CEND}. Continue? (y|n) : ")
            if ans.lower() == 'y':
                for node in domainNodes:
                    updateEverything(node['fqdn'])
            else:
                print('  Exiting...')
                sys.exit(2)
        else:
            print('  Invalid Resource Type. Please try again...')
            sys.exit(1)

    print()
    
if __name__ == "__main__":
    try:
        title()
        main()
    except KeyboardInterrupt:
        print('Interrupted')
        sys.exit(130)

## TODO: 
# - Check if no host keys are returned
