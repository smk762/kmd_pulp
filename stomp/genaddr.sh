#!/bin/bash

#Get Asset Chain Names from json file
ac_json=$(curl https://raw.githubusercontent.com/blackjok3rtt/StakedNotary/master/assetchains.json 2>/dev/null)
for row in $(echo "${ac_json}" | jq -c -r '.[]'); do
	_jq() {
		echo ${row} | jq -r ${1}
	}
	chain=$(_jq '.ac_name')
	touch .${chain}wallet
	sudo chmod 600 .${chain}wallet

	address=$(komodo-cli -ac_name=$chain getnewaddress)
	echo { \"chain\":\"${chain}\", >> .${chain}wallet
	echo \"addr\":\"${address}\", >> .${chain}wallet
	echo \"pk\":\"$(komodo-cli -ac_name=${chain} dumpprivkey $address)\", >> .${chain}wallet
	echo \"pub\":\"$(komodo-cli -ac_name=${chain} validateaddress $address | jq -r '.pubkey')\" } >> .${chain}wallet
done
