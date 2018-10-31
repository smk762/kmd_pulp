#!/usr/bin/env python3
import sys
import os
import json
import getconf
import colorTable

def selectRange(low,high, msg): 
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

# construct daemon url
i = 0
ID = 1
oracletxIDs = []
HOME = os.environ['HOME']
with open(HOME + '/StakedNotary/assetchains.json') as file:
	assetchains = json.load(file)

print(colorTable.colors[i]+ 'ID'.rjust(3) + ' | ' +'ASSET CHAIN'.ljust(12) + ' | ' + 'ORACLE NAME'.ljust(20) + ' | ' + 'ORACLE DESCIPTION'.ljust(50) + ' | ' + 'ORACLE TX ID')
for chain in assetchains:
	RPCURL = getconf.def_credentials(chain['ac_name'])
	oraclelist_result = getconf.oracleslist_rpc(chain['ac_name'])
	
	i+=1
	for oracle_txid in oraclelist_result:
		oraclesinfo_result = getconf.oraclesinfo_rpc(chain['ac_name'], oracle_txid)
		description = oraclesinfo_result['description']
		name = oraclesinfo_result['name']
		#		if description[0:3] == 'GPS':
		print(colorTable.colors[i]+ str(ID).rjust(3) + ' | ' + chain['ac_name'].ljust(12) + ' | ' + name.ljust(20) + ' | ' + description.ljust(50) + ' | ' + oracle_txid)
		oracletxIDs.append(oracle_txid)
		ID+=1
chosen_one = selectRange(0,len(oracletxIDs),"Select an oracle: ")
print("you selected oracle " + str(chosen_one) )
