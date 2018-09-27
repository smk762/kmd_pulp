#!/bin/bash

# This script creates transactions to quickly migrate your balance evenly across all active chains on the same -ac_cc id
total_balance=0
num_migrates=0
spread=5
sources=()
targets=()
addr_list=()
pending_migrations=0
complete_migrations=0
col_red="\e[31m"
col_green="\e[32m"
col_yellow="\e[33m"
col_blue="\e[34m"
col_magenta="\e[35m"
col_cyan="\e[36m"
col_default="\e[39m"
colors=($col_red $col_green $col_yellow $col_blue $col_magenta $col_cyan)



prompt_confirm() {
  while true; do
    read -r -n 1 -p "${1:-Continue?} [y/n]: " REPLY
    case $REPLY in
      [yY]) echo ; return 0 ;;
      [nN]) echo ; return 1 ;;
      *) printf " \033[31m %s \n\033[0m" "invalid input"
    esac
  done
}

# Get latest chain parameters
ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
num_chains=$(echo "${ac_json}" | jq  -r '. | length');
for chain in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
	chains+=($chain)
done


colorIndex=0
for chain in ${chains[@]}; do
	addresses=()
	num_addr=$(komodo-cli -ac_name=${chain} listaddressgroupings | jq -r '.[] | length')
	if [ -z $num_addr ] || [ $num_addr -lt 5  ]; then 
		echo -e "\e[91m WARNING: You have less than 5 active addresses for ${chain}."
		echo " This script creates an addresses to be used for cross chain coin migration."
		echo " The address, privkey, and pubkey are stored in a owner read-only file"
		echo -e "Make sure to encrypt, backup, or delete as required \e[39m"
		prompt_confirm "Create new addresses for ${chain}? (exit and ask in Discord if unsure)" || exit 0
		if [ ! -d ~/wallets  ]; then
			mkdir ~/wallets
		fi
		if [ ! -d ~/.komodo/${chain}  ]; then
			echo -e "\e[91m [ $chain ] CONF FILE DOES NOT EXIST!"
	                echo -e "Sync the chains first! \e[39m"
			exit 1
		fi
		if [ ! -f  ~/wallets/.${chain}_wallet ]; then
			touch  ~/wallets/.${chain}_wallet
			sudo chmod 600  ~/wallets/.${chain}_wallet
		fi
		for i in {1..5}; do
			address=$(komodo-cli -ac_name=$chain getnewaddress)
			echo "Created $address for [ $chain ]"
			echo { \"chain\":\"${chain}\", >> ~/wallets/.${chain}_wallet
			echo \"addr\":\"${address}\", >> ~/wallets/.${chain}_wallet
			echo \"pk\":\"$(komodo-cli -ac_name=${chain} dumpprivkey $address)\", >> ~/wallets/.${chain}_wallet
			echo \"pub\":\"$(komodo-cli -ac_name=${chain} validateaddress $address | jq -r '.pubkey')\" } >> ~/wallets/.${chain}_wallet
			addresses+=($address)
		done
		echo -e "\e[92m Finished: Your address info is located in ~/wallets \e[39m"
		first_addr=$address
		echo "$chain has 5 addresses."
		echo "first address is : $first_addr"
		echo "addr list: ${addresses[@]}"
	else

		first_addr=$(komodo-cli -ac_name=$chain listaddressgroupings | jq -r '.[][0][0]')
		addr_list="$(komodo-cli -ac_name=$chain listaddressgroupings | jq -r '.[][][0]')"
		addresses=()
		for addr in $addr_list; do
			for i in {1..5}; do
				addresses+=($addr)
			done
			break
		done
			echo "$chain has $num_addr addresses."
			echo "first address is : $first_addr"
			echo "addr list: ${addresses[@]}"

	fi
done