#!/usr/bin/env python3
import sys
import codecs
import requests
import time
import getconf

CHAIN = "CFEK"
ORCLID = "42b0a3a7cd32160cbe077145024f1fd585663e5e355dc70b92b38ff67cb776f3"
MSG = sys.argv[1]

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
print("bytelen: "+str(bytelen))
#convert big endian length to little endian, append rawhex to little endian length
lilend = bigend[2] + bigend[3] + bigend[0] + bigend[1]
print("lilend: "+str(lilend))
fullhex = lilend + rawhex
print("fullhex: "+str(fullhex))
oraclesdata_result = getconf.oraclesdata_rpc(CHAIN, ORCLID, fullhex)
print("oraclesdata_result: "+str(oraclesdata_result))
result = oraclesdata_result['result']
print("result: "+str(result))
if result == 'error':
    print('ERROR:' + oraclesdata_result['error'] + ', try using oraclesregister if you have not already')
rawtx = oraclesdata_result['hex']
print("rawtx: "+str(rawtx))
sendrawtx_result = getconf.sendrawtx_rpc(CHAIN, rawtx)
print("sendrawtx_result: "+str(sendrawtx_result))
print('MSG sent: '+str(MSG))
