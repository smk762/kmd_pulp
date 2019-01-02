#!/usr/bin/env python3
import os
import re
import sys
import time
import codecs
import requests
import json
import platform

#chain=sys.argv[0]
#orcl_id=sys.argv[1]
chain='CFEK'
orcl_id="155ea1645056c7e369b2bd1fb50c81608b8caac4d3bb1bf6f532f435f6d90d4d"

# define function that fetchs rpc creds from .conf
def def_credentials(chain):
	operating_system = platform.system()
	if operating_system == 'Darwin':
		ac_dir = os.environ['HOME'] + '/Library/Application Support/Komodo'
	elif operating_system == 'Linux':
		ac_dir = os.environ['HOME'] + '/.komodo'
	elif operating_system == 'Win64':
		ac_dir = "dont have windows machine now to test"
	# define config file path
	if chain == 'KMD':
		coin_config_file = str(ac_dir + '/komodo.conf')
	else:
		coin_config_file = str(ac_dir + '/' + chain + '/' + chain + '.conf')
	#define rpc creds
	with open(coin_config_file, 'r') as f:
		for line in f:
			l = line.rstrip()
			if re.search('rpcuser', l):
				rpcuser = l.replace('rpcuser=', '')
			elif re.search('rpcpassword', l):
				rpcpassword = l.replace('rpcpassword=', '')
			elif re.search('rpcport', l):
				rpcport = l.replace('rpcport=', '')
	return('http://' + rpcuser + ':' + rpcpassword + '@127.0.0.1:' + rpcport)

# define function that posts json data
def post_rpc(url, payload, auth=None):
	try:
		r = requests.post(url, data=json.dumps(payload), auth=auth)
		return(json.loads(r.text))
	except Exception as e:
		raise Exception("Couldn't connect to " + url + ": ", e)

def oraclesinfo_rpc(chain, oracletxid):
	oraclesinfo_payload = {
		"jsonrpc": "1.0",
		"id": "python",
		"method": "oraclesinfo",
		"params": [oracletxid]}
	oraclesinfo_result = post_rpc(def_credentials(chain), oraclesinfo_payload)
	return(oraclesinfo_result['result'])

def oraclesdata_rpc(chain, oracletxid, hexstr):
	oraclesdata_payload = {
		"jsonrpc": "1.0",
		"id": "python",
		"method": "oraclesdata",
		"params": [
			oracletxid,
			hexstr]}
	oraclesdata_result = post_rpc(def_credentials(chain), oraclesdata_payload)
	return(oraclesdata_result['result'])

def sendrawtx_rpc(chain, rawtx):
	sendrawtx_payload = {
		"jsonrpc": "1.0",
		"id": "python",
		"method": "sendrawtransaction",
		"params": [rawtx]}
	rpcurl = def_credentials(chain)
	return(post_rpc(def_credentials(chain), sendrawtx_payload))
	
def write2oracle(chain, orcl_id, MSG):
	print("MSG: " + str(MSG))
	rawhex = codecs.encode(MSG).hex()

	#get length in bytes of hex in decimal
	bytelen = int(len(rawhex) / int(2))
	hexlen = format(bytelen, 'x')

	#get length in big endian hex
	if bytelen < 16:
		bigend = "000" + str(hexlen)
	elif bytelen < 256:
		bigend = "00" + str(hexlen)
	elif bytelen < 4096:
		bigend = "0" + str(hexlen)
	elif bytelen < 65536:
		bigend = str(hexlen)
	else:
		print("message too large, must be less than 65536 characters")

	#convert big endian length to little endian, append rawhex to little endian length
	lilend = bigend[2] + bigend[3] + bigend[0] + bigend[1]
	fullhex = lilend + rawhex

	oraclesdata_result = oraclesdata_rpc(chain, orcl_id, fullhex)
	print(chain)
	print(orcl_id)
	print(fullhex)
	result = oraclesdata_result['result']

	if result == 'error':
		print('ERROR:' + oraclesdata_result['error'] + ', try using oraclesregister if you have not already')
	else:
		rawtx = oraclesdata_result['hex']
		sendrawtx_result = sendrawtx_rpc(chain, rawtx)
	return result


while True:
	rawdata = 'put the data you want to write to the oracle here'
	result = write2oracle(chain, orcl_id, rawdata)
	print('=========== Data written to Oracle  ===============')
	print('sleeping')
	time.sleep(300)