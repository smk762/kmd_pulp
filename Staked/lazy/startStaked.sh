#!/bin/bash
# Fetch assetchains.json


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
	if [ $ac_name == "KMD" ]; then
		acName_flag=""
	else	
		acName_flag="-ac_name=$ac_name"
	fi
	while [ -z $blocks ]; do
		info=$(echo $(komodo-cli $acName_flag getinfo)) > /dev/null 2>&1
		blocks=$(echo ${info} | jq -r '.blocks')
		longestchain=$(echo ${info} | jq -r '.longestchain')
		#echo "$ac_name longestchain: $longestchain"
		#echo "$ac_name blocks: $blocks"
		if [ -z $longestchain ]; then
			echo "[$ac_name not syncronised, checking again in 20 seconds"
	    	sleep 20			
		elif [ $longestchain != 0 ]; then
			if [ $blocks == $longestchain ]; then
				break 2;
			elif [ $blocks -eq 0 ]; then
				echo "Incompatible Komodo version. Check Discord to confirm you're on the right repo."
				exit 0;
			else
				progress=$(echo blocks/longestchain|bc)
				echo "[$ac_name not syncronised ($progress), checking again in 20 seconds"
		    	sleep 20
		    fi
		fi
	done
	echo "[$ac_name syncronised on block ${blocks}]"
}
startDaemon() {
	ac_name=$1
	ac_params=$2
	echo "Starting $ac_name ${ac_params[@]}"
	komodod $ac_params &
	if [ $ac_name == "KMD" ]; then
		acName_flag=""
	else	
		acName_flag="-ac_name=$ac_name"
	fi
	sleep 10
    checkSync $ac_name
	addresses=()
	addrss=$(komodo-cli $acName_flag listaddressgroupings | jq -r '.[][][0]')
	for addr in $addrss; do
		addresses+=($addr)
	done
	if [ ! -d ~/wallets  ]; then
		mkdir ~/wallets
	fi
	if [ ! -d ~/.komodo/${chain}  ]; then
		echo -e "\e[91m [ $chain ] CONF FILE DOES NOT EXIST!"
                echo -e "Sync the chains first! \e[39m"
		exit 1
	fi
	if [ ! -f  ~/wallets/.${ac_name}_wallet ]; then
		touch  ~/wallets/.${ac_name}_wallet
		chmod 600  ~/wallets/.${ac_name}_wallet
	fi

	num_addr=${#addresses[@]}
	echo "address count: $num_addr"
	if [ -z $num_addr ] || [ $num_addr==0 ]; then
		address=$(komodo-cli $acName_flag getnewaddress)
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
		echo "addr: $address"
	fi
	pubkey=$(komodo-cli $acName_flag validateaddress $address | jq -r '.pubkey')
	komodo-cli $acName_flag stop
	echo "waiting for $ac_name daemon to stop"
	PIDs=$(pgrep -a komodod)
	#echo "PIDS: $PIDs"
	PID=$(echo $PIDs | grep "$ac_name")
	#echo "PID: $PID"
	while [ "$PID" != "" ]; do
		echo "waiting for $ac_name deamon to stop"
	#	echo "PID: $PID"
		PID=$(echo $(pgrep -a komodod | grep "$ac_name"))
		sleep 15
	done
	echo "Using pubkey $pubkey for $ac_name address $address"
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
	echo $ac_params
	startDaemon $ac_name "$ac_params"
done
startDaemon "KMD"
echo "Komodo and all Staked chains deamons are activated. Use 'tail -f ~/.komodo/<ac_name>/debug.log' to view stdout"
# Start assets

