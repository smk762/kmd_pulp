#!/usr/bin/env python3
# pip3 install python-bitcoinlib

import sys
import getconf
import pprint
import bitcoin
import ast
from conf import CoinParams
from bitcoin.wallet import P2PKHBitcoinAddress
from bitcoin.core import x

CHAIN = sys.argv[1]
USERNAME = sys.argv[2]
PASSWORD = sys.argv[3]
pubkey = getconf.getpubkey_rpc(CHAIN)
bitcoin.params = CoinParams

addr = str(P2PKHBitcoinAddress.from_pubkey(x(pubkey)))
signmessage_result = getconf.signmessage_rpc(CHAIN, addr, USERNAME)
value = signmessage_result + USERNAME
print(CHAIN)
print(pubkey)
print(value)
print(PASSWORD)
kvupdate_result = getconf.kvupdate_rpc(CHAIN, pubkey, value, 100, PASSWORD)
print(kvupdate_result)
pprint.pprint(kvupdate_result['result'])

