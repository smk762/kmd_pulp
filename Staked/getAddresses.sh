#!/bin/bash

# This script creates transactions to quickly migrate your balance evenly across all active chains on the same -ac_cc id
addr_list=()
col_red="\e[31m"
col_green="\e[32m"
col_yellow="\e[33m"
col_blue="\e[34m"
col_magenta="\e[35m"
col_cyan="\e[36m"
col_default="\e[39m"
colors=($col_red $col_green $col_yellow $col_blue $col_magenta $col_cyan)
if [ -z $1 ]; then
	address_req=5
else
	address_req=$1
fi
echo $address_req

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
	addrss=$(komodo-cli -ac_name=${chain} listaddressgroupings | jq -r '.[][][0]')
	for addr in $addrss; do
		addresses+=($addr)
	done
	num_addr=${#addresses[@]}
	if [ -z $num_addr ]; then
		num_addr=0
	fi
	if [ $num_addr -lt $address_req  ]; then
		selected_addr=$addresses
		echo -e "\e[91m WARNING: You have less than $address_req active addresses for ${chain}."
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
			chmod 600  ~/wallets/.${chain}_wallet
		fi

		for (( i=${#selected_addr[@]}; i<$address_req; i++ )); do
			address=$(komodo-cli -ac_name=$chain getnewaddress)
			echo "Created $address for [ $chain ]"
			echo { \"chain\":\"${chain}\", >> ~/wallets/.${chain}_wallet
			echo \"addr\":\"${address}\", >> ~/wallets/.${chain}_wallet
			echo \"pk\":\"$(komodo-cli -ac_name=${chain} dumpprivkey $address)\", >> ~/wallets/.${chain}_wallet
			echo \"pub\":\"$(komodo-cli -ac_name=${chain} validateaddress $address | jq -r '.pubkey')\" } >> ~/wallets/.${chain}_wallet
			selected_addr+=($address)
		done
		num_addr=${#selected_addr[@]}
		# clean up the json
		echo $(cat ~/wallets/.${chain}_wallet | sed 's/[][]//g') > ~/wallets/.${chain}_wallet 
		echo $(cat ~/wallets/.${chain}_wallet | tr -d '\n') > ~/wallets/.${chain}_wallet
		echo $(cat ~/wallets/.${chain}_wallet | sed 's/} {/},\n{/g') > ~/wallets/.${chain}_wallet
		echo \[$(cat ~/wallets/.${chain}_wallet)\] > ~/wallets/.${chain}_wallet
		echo $(cat ~/wallets/.${chain}_wallet | sed '/},/{G;}') > ~/wallets/.${chain}_wallet
		# cat ~/wallets/.${chain}_wallet
		echo -e "\e[92m Finished: Your address info is located in ~/wallets \e[39m"
	else
		selected_addr=()
		for (( i=0; i<$address_req; i++ )); do
				selected_addr+=(${addresses[${i}]})
		done
	fi
	echo "$chain has $num_addr addresses (${#selected_addr[@]} selected)."
	echo "Selected address list: ${selected_addr[@]}"
done
# clean up wallet info json
