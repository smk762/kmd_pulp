#!/bin/bash

#Get Asset Chain Names from json file
echo -e "\e[91m WARNING: This script creates addresses to be use in pool config and payment processing"
echo " The address, privkey, and pubkey are stored in a owner read-only file"
echo -e " make sure to encrypt, backup, or delete as required \e[39m"
mkdir ~/kmd_pulp/stomp/wallets
ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
for row in $(echo "${ac_json}" | jq -c -r '.[]'); do
	_jq() {
		echo ${row} | jq -r ${1}
	}
	chain=$(_jq '.ac_name')
	if [ ! -f  ~/kmd_pulp/stomp/wallets/.${chain}_wallet ]; then
		touch  ~/kmd_pulp/stomp/wallets/.${chain}_wallet
		sudo chmod 600  ~/kmd_pulp/stomp/wallets/.${chain}_wallet
		address=$(komodo-cli -ac_name=$chain getnewaddress)
		echo "Created $address for [ $chain ]"
		echo { \"chain\":\"${chain}\", >> ~/kmd_pulp/stomp/wallets/.${chain}_wallet
		echo \"addr\":\"${address}\", >> ~/kmd_pulp/stomp/wallets/.${chain}_wallet
		echo \"pk\":\"$(komodo-cli -ac_name=${chain} dumpprivkey $address)\", >> ~/kmd_pulp/stomp/wallets/.${chain}_wallet
		echo \"pub\":\"$(komodo-cli -ac_name=${chain} validateaddress $address | jq -r '.pubkey')\" } >> ~/kmd_pulp/stomp/wallets/.${chain}_wallet
	else
		echo "ADDRESS FOR $chain ALREADY CREATED";
	fi
done
echo -e "\e[92m Finished: Your address info is located in ~/kmd_pulp/stomp/wallets \e[39m"
