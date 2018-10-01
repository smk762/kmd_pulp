#!/bin/bash

col_red="\e[31m"
col_green="\e[32m"
col_yellow="\e[33m"
col_blue="\e[34m"
col_magenta="\e[35m"
col_cyan="\e[36m"
col_default="\e[39m"
col_ltred="\e[91m"
col_ltgreen="\e[92m"
col_ltyellow="\e[93m"
col_ltblue="\e[94m"
col_ltmagenta="\e[95m"
col_dkgrey="\e[90m"
colors=($col_ltgreen $col_ltblue $col_ltmagenta $col_cyan $col_ltyellow)
dice_tables=()

# Set chain dice is being played on

listTables() {
	header=" %-3s %-12s %-10s  %7s  %7s  %8s  %7s  %5s  %-64s\n"
	format=" %-3s %-12s %-10s  %7d  %7d  %8d  %7d  %5.0f  %-64s\n"
	i=1
	ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
	num_chains=$(echo "${ac_json}" | jq  -r '. | length');
	echo -e "${col_yellow}------------------------------------------------------------------------------------------------------------------------------------------${col_default}"
	echo -e "${col_yellow}----------------------------------------------------- ${col_cyan} S E L E C T   A   T A B L E ${col_yellow} ------------------------------------------------------"
	echo -e "${col_yellow}------------------------------------------------------------------------------------------------------------------------------------------${col_default}"
	printf "$header" "#" "CHAIN" "TABLE NAME" "MIN BET" "MAX BET" "MAX ODDS" "TIMEOUT" "FUNDS" "TX"
	for chain_params in $(echo "${ac_json}" | jq  -c -r '.[]'); do
		j=$(( $i % ${#colors[@]} ))
		echo -e ${colors[$j]}
	    ac_private=$(echo $chain_params | jq -r '.ac_private')
	    if [[ $ac_private != 1 ]]; then
		    ac_name=$(echo $chain_params | jq -r '.ac_name')
			diceList=$(komodo-cli -ac_name=$ac_name dicelist)
			diceList="$(echo $diceList | jq -r '.[]')"
			for table in $diceList; do
				dice_tables+=("$table")
				tableInfo=$(komodo-cli -ac_name=$ac_name diceinfo $table)
				result=$(echo $tableInfo | jq -r '.result')
				name=$(echo $tableInfo | jq -r '.name')
				sbits=$(echo $tableInfo | jq -r '.sbits')
				minbet=$(echo $tableInfo | jq -r '.minbet')
				minbet=${minbet%.*}
				maxbet=$(echo $tableInfo | jq -r '.maxbet')
				maxbet=${maxbet%.*}
				maxodds=$(echo $tableInfo | jq -r '.maxodds')
				timeout=$(echo $tableInfo | jq -r '.timeoutblocks')
				funding=$(echo $tableInfo | jq -r '.funding')
				printf "$format" "$i" "$ac_name" "$name" "$minbet" "$maxbet" "$maxodds" "$timeout" "$funding" "$table"
				((i=$i+1))
			done
		fi	
	done
	echo -e "${col_yellow}------------------------------------------------------------------------------------------------------------------------------------------${col_default}"
	numTables=${#dice_tables[@]}
	tableIndex=$(echo $numTables+1|bc)
	while [[ true ]]; do
		echo -e "${col_yellow}"
		read -p "Select table number: " tableIndex
		echo -e "${col_default}"
		if [ $tableIndex -ge 0 2>/dev/null ]; then	
			if [[ $tableIndex -gt $numTables ]]; then
				echo -e "${col_ltred}Invalid table number, try again.${col_default}"
			else
				break
			fi
		else
			echo -e "${col_ltred}Invalid input, try again.${col_default}"
		fi
	done
}
listTables