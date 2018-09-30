#!/bin/bash
# Fetch assetchains.json
col_red="\e[31m"
col_green="\e[32m"
col_yellow="\e[33m"
col_blue="\e[34m"
col_magenta="\e[35m"
col_cyan="\e[36m"
col_default="\e[39m"
col_ltred="\e[91m"
col_dkgrey="\e[90m"
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
checkSync() {
	ac_name=$1
	echo -e "${col_blue}Checking $ac_name sync${col_default}"
	if [ $ac_name == "KMD" ]; then
		acName_flag=""
	else	
		acName_flag="-ac_name=$ac_name"
	fi
	while [ -z $blocks ]; do
		info=$(echo $(komodo-cli $acName_flag getinfo)) > /dev/null 2>&1 
		blocks=$(echo ${info} | jq -r '.blocks')
		longestchain=$(echo ${info} | jq -r '.longestchain')
		if [ -z $longestchain ]; then
			echo -e "${col_blue}[$ac_name not syncronised, checking again in 20 seconds${col_default}"
	    	sleep 20
		elif [ $longestchain != 0 ]; then
			if [ $blocks == $longestchain ]; then
				echo -e "${col_yellow} [$ac_name syncronised on block ${blocks}]${col_default}"
				break;
			elif [ $blocks -eq 0 ]; then
				echo -e "${col_red}Incompatible Komodo version. Check Discord to confirm you're on the right repo.${col_default}"
				exit 0;
			else
				progress=$(echo blocks/longestchain|bc)
				echo -e "${col_blue}[$ac_name not syncronised ($progress), checking again in 20 seconds${col_default}"
		    	sleep 20
		    fi
		fi
	done
	echo -e "${col_green} [$ac_name syncronised on block ${blocks}]${col_default}"
}
checkStopped() {
	ac_name="$1"
	acName_flag="$2"
	echo -e "${col_blue}Checking $ac_name stopped${col_default}"
	ac_info=$(komodo-cli $acName_flag getinfo) > /dev/null 2>&1
	ac_infoName=$(echo $ac_info | jq -r '.name') > /dev/null 2>&1
	while [[ $ac_name == $ac_infoName  ]]; do
		echo -e "${col_blue}waiting for $ac_name deamon to stop${col_default}"
		sleep 15
		ac_info=$(komodo-cli $acName_flag getinfo) > /dev/null 2>&1
		ac_infoName=$(echo $ac_info | jq -r '.name') > /dev/null 2>&1
	done
	echo -e "${col_green}$ac_name stopped${col_default}"
}

startDaemon() {
	ac_name=$1
	ac_params=$2
	#echo "Starting $ac_name ${ac_params[@]}"
	if [ $ac_name == "KMD" ]; then
		acName_flag=""
	else	
		acName_flag="-ac_name=$ac_name"
	fi
	komodod $ac_params  > /dev/null 2>&1 &
	sleep 15
    checkSync $ac_name
	addresses=()
	addrss=$(komodo-cli $acName_flag listaddressgroupings | jq -r '.[][][0]') > /dev/null 2>&1
	for addr in $addrss; do
		addresses+=($addr)
	done
	if [ ! -d ~/wallets  ]; then
		mkdir ~/wallets
	fi
	if [ ! -d ~/.komodo/${ac_name}  ]; then
		echo -e "\e[91m [ $chain ] CONF FILE DOES NOT EXIST!"
                echo -e "Sync the chains first! \e[39m"
		exit 1
	fi
	if [ ! -f  ~/wallets/.${ac_name}_wallet ]; then
		touch  ~/wallets/.${ac_name}_wallet
		chmod 600  ~/wallets/.${ac_name}_wallet
	fi
	num_addr=${#addresses[@]}
	if [ -z $num_addr ] || [ $num_addr==0 ]; then
		address=$(komodo-cli $acName_flag getnewaddress) > /dev/null 2>&1
		while [[ ${#address} != 34 ]]; do
			echo ${#address}
			sleep 30
			address=$(komodo-cli $acName_flag getnewaddress) > /dev/null 2>&1
		done
		echo \{ \"chain\":\"${ac_name}\", >> ~/wallets/.${ac_name}_wallet
		echo \"addr\":\"${address}\", >> ~/wallets/.${ac_name}_wallet
		echo \"pk\":\"$(komodo-cli $acName_flag dumpprivkey $address)\", >> ~/wallets/.${ac_name}_wallet
		echo \"pub\":\"$(komodo-cli $acName_flag validateaddress $address | jq -r '.pubkey')\" \} >> ~/wallets/.${ac_name}_wallet
		echo -e "\e[92m Using address $address for [ $ac_name ] (info is located in ~/wallets/.${ac_name}_wallet) \e[39m"
		num_addr=1
		# clean up the json
		echo $(cat ~/wallets/.${ac_name}_wallet | sed 's/[][]//g') > ~/wallets/.${ac_name}_wallet 
		echo $(cat ~/wallets/.${ac_name}_wallet | tr -d '\n') > ~/wallets/.${ac_name}_wallet
		echo $(cat ~/wallets/.${ac_name}_wallet | sed 's/} {/},\n{/g') > ~/wallets/.${ac_name}_wallet
		echo \[$(cat ~/wallets/.${ac_name}_wallet)\] > ~/wallets/.${ac_name}_wallet
		echo $(cat ~/wallets/.${ac_name}_wallet | sed '/},/{G;}') > ~/wallets/.${ac_name}_wallet
		# cat ~/wallets/.${ac_name}_wallet		
	else
		address=${addresses[0]}
	fi
	pubkey=$(komodo-cli $acName_flag validateaddress $address | jq -r '.pubkey') > /dev/null 2>&1
	komodo-cli $acName_flag stop  > /dev/null 2>&1
	sleep 15
	checkStopped $ac_name $acName_flag
	echo -e "${col_blue} Using pubkey $pubkey for $ac_name address $address${col+default}"
	komodod $ac_params -pubkey=$pubkey > /dev/null 2>&1 &
}

ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
num_chains=$(echo "${ac_json}" | jq  -r '. | length');
for chain_params in $(echo "${ac_json}" | jq  -c -r '.[]'); do
    ac_name=$(echo $chain_params | jq -r '.ac_name')
    ac_supply=$(echo $chain_params | jq -r '.ac_supply')
    ac_reward=$(echo $chain_params | jq -r '.ac_reward')
    ac_staked=$(echo $chain_params | jq -r '.ac_staked')
    ac_end=$(echo $chain_params | jq -r '.ac_end')
    ac_cc=$(echo $chain_params | jq -r '.ac_cc')
    ac_perc=$(echo $chain_params | jq -r '.ac_perc')
    ac_pubkey=$(echo $chain_params | jq -r '.ac_pubkey')
    nodes=$(echo $chain_params | jq -r '.addnode')
    ac_params="-ac_name=$ac_name -ac_supply=$ac_supply -ac_reward=$ac_reward -ac_staked=$ac_staked -ac_end=$ac_end -ac_cc=$ac_cc -ac_perc=$ac_perc -ac_pubkey=$ac_pubkey"
    for node in $(echo $nodes | jq -r '.[]'); do
		ac_params+=" -ac_node=$node"
    done
	# echo $ac_params
	echo -e "${col_green}Starting $ac_name Daemon${col_default}"
	startDaemon $ac_name "$ac_params"
done
echo -e "${col_green}Starting KMD Daemon${col_default}"
startDaemon "KMD"
echo -e "${col_green}Komodo and all Staked chains deamons are activated. Use ${col_yellow} tail -f ~/.komodo/<ac_name>/debug.log ${col_green} to view stdout${col_default}"
# Start assets

