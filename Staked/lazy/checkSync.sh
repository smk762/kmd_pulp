#!/bin/bash

# yet to test version checking - "longest chain can get lost quite easily on early chains, might need some extra check 
# @webworker01 has some code that checks explorers heights, which might be a good way to go, but we have to have explorers up first.

ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
for row in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
	chain=$(echo $row)
	info=$(echo $(komodo-cli -ac_name=${chain} getinfo))
	blocks=$(echo ${info} | jq -r '.blocks')
	longestchain=$(echo ${info} | jq -r '.longestchain')
	while [[ $blocks < $longestchain ]]; do
		progress=$(echo blocks/longestchain|bc)
	        echo "[${chain} chain not syncronised. On block ${blocks} of ${longestchain}] $(echo $progress*100 | bc)%"
		echo "will check again in 30 seconds"
        	sleep 30
	done
	echo "[${chain} chain syncronised on block ${blocks}]"
done

kmdinfo=$(echo $(komodo-cli getinfo))
kmd_blocks=$(echo ${kmdinfo} | jq -r '.blocks')
kmd_longestchain=$(echo ${kmdinfo} | jq -r '.longestchain')

if [[ $kmd_longestchain == 0 ]]; then
        echo -e "\e[91m ** [Incompatible Komodo version. Join #staked on discord at https://discord.gg/tKRzWe to get latest version. ** \e[39m"
        exit 0;
fi

while [[ $kmd_blocks < $kmd_longestchain ]]; do
	kmd_progress=$(echo $kmd_blocks/$kmd_longestchain|bc)
	echo "[Komodo chain not syncronised. On block ${kmd_blocks} of ${kmd_longestchain}] $(echo $progress*100|bc)%"
        echo "will check again in 30 seconds"
	sleep 30
done
echo "[Komodo chain syncronised on block ${kmd_blocks}]"
