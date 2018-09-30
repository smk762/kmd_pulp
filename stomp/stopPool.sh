#!/bin/bash

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
echo "stopping redis"
pkill -9 redis
echo "stopping stomp"
pkill -9 node
echo "stopping pool start scripts"
pkill -9 startPool.sh
pkill -9 startStaked.sh
echo "stopping daemons"
komodo-cli stop > /dev/null 2>&1 &
staked-cli stop > /dev/null 2>&1 &
ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
for chain_params in $(echo "${ac_json}" | jq  -c -r '.[]'); do
    ac_name=$(echo $chain_params | jq -r '.ac_name')
	checkStopped $ac_name 
done
checkStopped "KMD" 

