#!/usr/bin/env python3

from slickrpc import Proxy
import time
import sys
import datetime
import os
import json
import re
import platform
import multiprocessing

max_threads=multiprocessing.cpu_count()

def selectRangeInt(low,high, msg): 
    while True:
        try:
            number = int(input(msg))
        except ValueError:
            print("integer only, try again")
            continue
        if low <= number <= high:
            return number
        else:
            print("input outside range, try again")

# define function that fetchs rpc creds from .conf
def def_credentials(chain):
    rpcport ='';
    operating_system = platform.system()
    if operating_system == 'Darwin':
        ac_dir = os.environ['HOME'] + '/Library/Application Support/Komodo'
    elif operating_system == 'Linux':
        ac_dir = os.environ['HOME'] + '/.komodo'
    elif operating_system == 'Win64':
        ac_dir = "dont have windows machine now to test"
    if chain == 'KMD':
        coin_config_file = str(ac_dir + '/komodo.conf')
    else:
        coin_config_file = str(ac_dir + '/' + chain + '/' + chain + '.conf')
    with open(coin_config_file, 'r') as f:
        for line in f:
            l = line.rstrip()
            if re.search('rpcuser', l):
                rpcuser = l.replace('rpcuser=', '')
            elif re.search('rpcpassword', l):
                rpcpassword = l.replace('rpcpassword=', '')
            elif re.search('rpcport', l):
                rpcport = l.replace('rpcport=', '')
    if len(rpcport) == 0:
        print("rpcport not in conf file, exiting")
        print("check "+coin_config_file)
        exit(1)

    return(Proxy("http://%s:%s@127.0.0.1:%d"%(rpcuser, rpcpassword, int(rpcport))))

HOME = os.environ['HOME']
with open(HOME + '/StakedNotary/assetchains.json') as file:
    assetchains = json.load(file)

assetChains = []
ID=1
for chain in assetchains:
    print(str(ID).rjust(3) + ' | ' + chain['ac_name'].ljust(12))
    ID+=1
    assetChains.append(chain['ac_name'])
src_chain = selectRangeInt(1,len(assetchains),"Select chain: ")
rpc_connection = def_credentials(assetChains[src_chain-1])
chain_status=rpc_connection.getgenerate()
if chain_status['generate']: 
	if int(chain_status['numthreads']) == 0:
		status = assetChains[src_chain-1]+" is staking"
	else:
		status = assetChains[src_chain-1]+" is mining with "+str(chain_status['numthreads'])+" threads"
else:
	status =  assetChains[src_chain-1]+" is idle"
print('Status: '+status)
chain_balance=rpc_connection.getbalance()
print('Balance: '+str(chain_balance))
gen_states=['mining on', 'staking on', 'mining/staking off', 'exit' ]

ID=1
for state in gen_states:
    print(str(ID).rjust(3) + ' | ' + gen_states[ID-1].ljust(12))
    ID+=1
    assetChains.append(chain['ac_name'])

gen_option = selectRangeInt(1,len(gen_states),"Select option: ")
if gen_option == 1:
	numthreads = selectRangeInt(1,max_threads,"How many threads (max "+str(max_threads)+"): ")
	print('starting miner')
	rpc_connection.setgenerate(True, numthreads)
elif gen_option == 2:	
	print('starting staker')
	rpc_connection.setgenerate(True, 0)
elif gen_option == 3:	
	print('stopping mining/staking')
	rpc_connection.setgenerate(False)
elif gen_option == 4:
	print('Goodbye!')
	exit(1)
else:
	print('Invalid selection!')
	exit(1)
time.sleep(2)
chain_status=rpc_connection.getgenerate()
if chain_status['generate']: 
	if int(chain_status['numthreads']) == 0:
		status = assetChains[src_chain-1]+" is staking"
	else:
		status = assetChains[src_chain-1]+" is mining with "+str(chain_status['numthreads'])+" threads"
else:
	status =  assetChains[src_chain-1]+" is idle"
print('Status: '+status)
chain_balance=rpc_connection.getbalance()
print('balance: '+str(chain_balance))