#!/usr/bin/env python3
import sys
import os
import json
import getconf
import colorTable

# construct daemon url
i = 0
OKBLUE = '\033[94m'
HOME = os.environ['HOME']
with open(HOME + '/StakedNotary/assetchains.json') as file:
    assetchains = json.load(file)

for chain in assetchains:
	RPCURL = getconf.def_credentials(chain['ac_name'])
	oraclelist_result = getconf.oracleslist_rpc(chain['ac_name'])
	i+=1
	for oracle_txid in oraclelist_result:
		oraclesinfo_result = getconf.oraclesinfo_rpc(chain['ac_name'], oracle_txid)
		description = oraclesinfo_result['description']
		name = oraclesinfo_result['name']
		#	    if description[0:3] == 'GPS':
		print(colorTable.colors[i] + chain['ac_name'] + ' | ' + name.ljust(20) + ' | ' + description.ljust(50) + ' | ' + oracle_txid)

