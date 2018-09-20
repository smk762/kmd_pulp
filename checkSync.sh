#!/bin/bash
echo "Checking chains are in sync..."

let numchains=1
let count=0;
kmdinfo=$(echo $(komodo-cli getinfo))
kmd_blocks=$(echo ${kmdinfo} | jq -r '.blocks')
kmd_longestchain=$(echo ${kmdinfo} | jq -r '.longestchain')
if [[ $kmd_blocks == $kmd_longestchain ]]; then
	let count=count+1;
	echo "[Komodo chain syncronised on block ${kmd_blocks}]"
else if [ $kmd_longestchain == 0 ]; then
	echo -e "\e[91m ** [Incompatible Komodo version. Join #staked on discord at https://discord.gg/tKRzWe to get latest version. ** \e[39m"
	exit 0;
else
	echo "[Komodo chain not syncronised. On block ${kmd_blocks} of ${kmd_longestchain}]"
fi


ac_json=$(curl https://raw.githubusercontent.com/blackjok3rtt/StakedNotary/master/assetchains.json 2>/dev/null)
for row in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
	let numchains=numchains+1;
	chain=$(echo $row)
	info=$(echo $(komodo-cli -ac_name=${chain} getinfo))
	blocks=$(echo ${info} | jq -r '.blocks')
	longestchain=$(echo ${info} | jq -r '.longestchain')
	if [[ $blocks == $longestchain ]]; then
		let count=count+1;
		echo "[${chain} chain syncronised on block ${blocks}]"
	else
		echo "[${chain} chain not syncronised. On block ${kmd_blocks} of ${kmd_longestchain}]"
	fi
done

if [[ $count == $numchains ]]; then
	echo "[ ALL SYSTEMS GO! ${count} / ${numchains} chains syncronised ]"
else
	echo "[ NOT ALL CHAINS IN SYNC (${count} / ${numchains}) ]"
fi
