#!/usr/bin/env python3
import sys
import codecs
import requests
import time
import getconf

CHAIN = "CFEK"
ORCLID = "efc4cb305f174f91b62c02a777d8347c099f9ba2f583e4de39cee53b6aece80b"
MSG = sys.argv[1]
print("MSG: " + MSG)
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

print("fullhex: "+ fullhex)
oraclesdata_result = getconf.oraclesdata_rpc(CHAIN, ORCLID, fullhex)
print(str(oraclesdata_result))
result = oraclesdata_result['result']
if result == 'error':
    print('ERROR:' + oraclesdata_result['error'] + ', try using oraclesregister if you have not already')
rawtx = oraclesdata_result['hex']

sendrawtx_result = getconf.sendrawtx_rpc(CHAIN, rawtx)