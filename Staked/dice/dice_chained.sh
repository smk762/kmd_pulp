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
dice_tables=()


rollDice() {
	ac_name=$1
	echo ""
	echo -e "${col_green}Step 2: Ask Ashy Larry: Are there are any games on? ${col_default}"
	echo ""
	diceList=$(komodo-cli -ac_name=$ac_name dicelist)
	diceList="$(echo $diceList | jq -r '.[]')"
	i=1
	for table in $diceList; do
		echo -e "${col_cyan}$i - $table${col_default}"
		((i=$i+1))
		dice_tables+=("$table")
	done
	numTables=${#dice_tables[@]}
	tableIndex=$(echo $numTables+1|bc)
	while [[ true ]]; do
		echo -e "${col_blue}"
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
	tableIndex=$(echo $tableIndex-1|bc)
	funding_txid="${dice_tables[${tableIndex}]}"
	echo -e "${col_dkgrey}funding_txid: $funding_txid${col_default}"
	echo ""
	echo -e "${col_green}Step 3: Ask Ashy Larry about the table${col_default}"
	tableInfo=$(komodo-cli -ac_name=$ac_name diceinfo $funding_txid)
	echo -e "${col_dkgrey}Funding TX: $funding_txid${col_default}"
	result=$(echo $tableInfo | jq -r '.result')
	name=$(echo $tableInfo | jq -r '.name')
	sbits=$(echo $tableInfo | jq -r '.sbits')
	minbet=$(echo $tableInfo | jq -r '.minbet')
	minbet=${minbet%.*}
	maxbet=$(echo $tableInfo | jq -r '.maxbet')
	maxbet=${maxbet%.*}
	maxodds=$(echo $tableInfo | jq -r '.maxodds')
	timeoutblocks=$(echo $tableInfo | jq -r '.timeoutblocks')
	funding=$(echo $tableInfo | jq -r '.funding')

	echo -e "${col_yellow} ---- TABLE RULES ----"
	echo "Minimum Bet: $minbet"
	echo "Maximum Bet: $maxbet"
	echo "Maximum Odds: $maxodds"
	echo "Timeout: $timeoutblocks blocks"
	echo -e "Table Funds: $funding${col_default}"

	echo ""
	echo -e "${col_green}Step 4: Tell Ashy Larry what bet you want to place${col_default}"
	amount=0
	# Todo: add filtering for non-numeric
	while [ true ] ; do
		echo -e "${col_blue}"
		read -p "Bet amount ($minbet - $maxbet)?" amount
		echo -e "${col_default}"
		if [ $amount -ge 0 2>/dev/null ]; then	
			if [ $amount -gt $maxbet ]; then
				echo -e "${col_ltred}Bet is more than table maximum, try again.${col_default}"
			elif [ $amount -lt $minbet ] ; then
				echo -e "${col_ltred}Bet is less than table minimum, try again.${col_default}"
			else
				break
			fi
		else
			echo -e "${col_ltred}Invalid input, try again.${col_default}"
		fi
	done
	odds=0
	while [ true ] ; do
		echo -e "${col_blue}"
		read -p "Odds (1 - $maxodds)?" odds
		echo -e "${col_default}"
		if [ $odds -ge 0 2>/dev/null ]; then
			if [ $odds -gt $maxodds ]; then
				echo -e "${col_ltred}Odds are more than table maximum, try again.${col_default}"
			elif [ $odds -lt 1 ] ; then
				echo -e "${col_ltred}Odds value not valid, try again.${col_default}"
			else
				break
			fi
		else
			echo -e "${col_ltred}Invalid input, try again.${col_default}"
		fi
	done

	echo -e "${col_magenta}Placing bet on table [$name] (funding txid: $funding_txid) for $amount $ac_name at $odds to 1 odds ${col_default}"
	bet=$(komodo-cli -ac_name=$ac_name dicebet $name $funding_txid $amount $odds)
	bet_hex=$(echo $bet | jq -r '.hex')
	placed_bet=$(echo $bet | jq -r '.result')
	while [ "$placed_bet" == "error" ]; do
		bet=$(komodo-cli -ac_name=$ac_name dicebet $name $funding_txid $amount $odds)
		bet_hex=$(echo $bet | jq -r '.hex')
		placed_bet=$(echo $bet | jq -r '.result')
		if [ $placed_bet == "error" ]; then
			echo " waiting for next roll"
			echo -e "${col_dkgrey}Bet: ${bet}${col_default}"
		fi
		sleep 15
	done
	echo -e "${col_dkgrey}Bet Hex: $bet_hex${col_default}"
	echo ""
	echo -e "${col_green}Step 5: Tell Ashy Larry to confirm your bet ${col_default}"
	echo -e "${col_blue}Creating bet txid"
	bet_txid=$(komodo-cli -ac_name=$ac_name sendrawtransaction $bet_hex)
	echo -e "${col_dkgrey}Bet TX: $bet_txid${col_default}"
	echo $bet_txid >> ~/wallets/.${ac_name}_dicewallet_bets
	echo -e "${col_magenta}Placing bet on table [$name] with (bet_txid: $bet_txid) for $amount $ac_name at $odds to 1${col_default}"
	rawmempool=$(komodo-cli -ac_name=$ac_name getrawmempool)
	confirmbet=$(echo $rawmempool | jq '.[]' | grep $bet_txid)
	while [ -z "$confirmbet" ]; do
		echo -e "${col_dkgrey}waiting for confirmation${col_default}"
		sleep 10
		rawmempool=$(komodo-cli -ac_name=$ac_name getrawmempool)
		confirmbet=$(echo $rawmempool | grep $bet_txid)
	done
	betblockinfo=$(komodo-cli -ac_name=$ac_name getinfo)
	betblock=$(echo $betblockinfo | jq -r '.blocks')
	echo -e "${col_green}Bet confirmed in mempool with with txid: $confirmbet${col_default} on block $betblock"

	echo ""
	echo -e "${col_green}Step 6: Wait for Ashy Larry to roll the dice ${col_default}"
	echo -e "${col_dkgrey}creating bet finish${col_default}"
	bet_finish=$(komodo-cli -ac_name=$ac_name dicefinish $name $funding_txid $bet_txid)
	betFinish_result=$(echo $bet_finish | jq -r '.result')
	betFinish_error=$(echo $bet_finish | jq -r '.error')

	roll_start=$SECONDS
	echo -e "${col_cyan}Placing bet on table [$name] with (bet_txid: $bet_txid) for $amount $ac_name at $odds to 1${col_default}"
	while [ $betFinish_result != "success" ]; do
		bet_finish=$(komodo-cli -ac_name=$ac_name dicefinish $name $funding_txid $bet_txid)
		chainblockinfo=$(komodo-cli -ac_name=$ac_name getinfo)
		chainblock=$(echo $chainblockinfo | jq -r '.blocks')
		confblocks=$(echo $chainblock-$betblock|bc)
		roll_time=$(echo $SECONDS-$roll_start|bc);
		betFinish_result=$(echo "$bet_finish" | jq -r '.result')
		betFinish_error=$(echo $bet_finish | jq -r '.error')
		if [[ $betFinish_result != "success" ]]; then
			echo -e "${col_blue}Waiting for dice to stop rolling ($roll_time sec - $confblocks / $timeoutblocks timeout blocks${col_default}"
			sleep 30		
		fi
	done
	echo -e "${col_dkgrey}Bet Finish: $bet_finish${col_default}"

	echo ""
	echo -e "${col_green}Step 7: Ask Ashy Larry if the result is ready ${col_default}"
	echo -e "${col_cyan}creating bet_result${col_default}"
	bet_status=$(komodo-cli -ac_name=$ac_name dicestatus $name $funding_txid $bet_txid)
	betStatus_result=$(echo $bet_status | jq -r '.result')
	echo -e "${col_dkgrey}status: $bet_status${col_default}"
	echo -e "${col_dkgrey}result: $betStatus_result${col_default}"
	while [ $betStatus_result != "success" ]; do
		echo "waiting for result"
		betStatus=$(komodo-cli -ac_name=$ac_name dicestatus $name $funding_txid $bet_txid)
		betStatus_result=$(echo $betStatus | jq -r '.result')
		echo -e "${col_dkgrey}status: $bet_status${col_default}"
	done

	echo ""
	echo -e "${col_green}Step 8: Ask Ashy Larry what the result is ${col_default}"
	outcome=$(echo $bet_status | jq -r '.status')
	echo -e "${col_cyan}Checking outcome${col_default}"
	echo -e "${col_yellow}$outcome${col_default}"
	if [ $outcome == "loss" ]; then
		echo -e "${col_ltred}Ay! Larry! Get your broke ass back in the house! (lost $amount $ac_name)${col_default}"
	elif [ $outcome == "bet still pending" ]; then
		echo "dice are still rolling"
	else 
		winnings=$(echo $amount*$odds|bc)
		echo -e "${col_green} I'm Rich Biatch! (won $winnings $ac_name)${col_default}"
	fi
	echo ""
	while [ $outcome != "loss" ] && [ $outcome != "win" ]; do
		outcome=$(echo $bet_status | jq '.status')
		echo -e "${col_blue}outcome: $outcome${col_default}"
		if [ $outcome == "loss" ]; then
			echo -e "${col_ltred}Ay! Larry! Get your broke ass back in the house! (lost $amount $ac_name)${col_default}"
		elif [ $outcome == "bet still pending" ]; then
			echo "dice are still rolling"
		else 
			winnings=$(echo $amount*$odds|bc)
			echo -e "${col_green} I'm Rich Biatch! (won $winnings $ac_name)${col_default}"
			break
		fi
	done
	balance=$(komodo-cli -ac_name=$ac_name getbalance)
	echo -e "${col_magenta} You now have $balance $ac_name to bet${col_default}"
	unset addict
	while [[ $addict != "y" ]] && [[ $addict != "n" ]]; do
		echo -e "${col_green}"
		read -p "===== Roll again? [y/n] =====" addict
		echo -e "${col_default}"
		if [[ $addict == "y" ]]; then
			rollDice $ac_name
			break
		elif [[ $addict == "n" ]]; then
			echo -e "${col_yellow}--- Thanks for playing! ---${col_default}"
			exit 0
		else
			echo "Invalid response, try again."
		fi
	done
}

# Checking if asset chain selected is configured
if [ ! -d ~/.komodo/${ac_name}  ]; then
	echo -e "\e[91m [ $ac_name ] CONF FILE DOES NOT EXIST!"
            echo -e "Sync the chains first! \e[39m"
	exit 1
fi


echo -e "${col_blue}********************************************************************"
echo -e "**** KOMODO's STAKED CHAINS - DICE CRYPTO-CONDITIONS BET EXAMPLE ****"
echo -e "********************************************************************${col_default}"
echo ""


ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
num_chains=$(echo "${ac_json}" | jq  -r '. | length');
for chain_params in $(echo "${ac_json}" | jq  -c -r '.[]'); do
    ac_name=$(echo $chain_params | jq -r '.ac_name')
    ac_private=$(echo $chain_params | jq -r '.ac_private')
    if [[ $ac_private != 1 ]]; then
		echo -e "${col_green}Step 1: Setting up DICE address for $ac_name${col_default}"
		if [ ! -d ~/wallets  ]; then
			mkdir ~/wallets
		fi

		if [ ! -f  ~/wallets/.${ac_name}_dicewallet_bets ]; then
			echo -e "${col_cyan}Creating new dice wallet bet record. It will be saved in ~/wallets/.${ac_name}_dicewallet_bets${col_default}"
			touch  ~/wallets/.${ac_name}_dicewallet_bets
			chmod 600  ~/wallets/.${ac_name}_dicewallet_bets
		fi
		if [ ! -f  ~/wallets/.${ac_name}_dicewallet ]; then
			touch  ~/wallets/.${ac_name}_dicewallet
			chmod 600  ~/wallets/.${ac_name}_dicewallet
			new_addr=$(komodo-cli getnewaddress)
			new_pubkey=$(komodo-cli -ac_name=${ac_name} validateaddress $new_addr | jq -r '.pubkey')
			dice_addrInfo=$(komodo-cli -ac_name=$ac_name diceaddress $new_pubkey)
			myaddress=$(echo $dice_addrInfo | jq -r '.myaddress')
			echo -e "${col_cyan}Creating new dice wallet address {$myaddress}. It will be saved in ~/wallets/.${ac_name}_dicewallet${col_default}"
			echo $dice_addrInfo >  ~/wallets/.${ac_name}_dicewallet
		else
			dice_addrInfo=$(cat ~/wallets/.${ac_name}_dicewallet)
			myaddress=$(echo $dice_addrInfo | jq -r '.myaddress')
			echo -e "${col_cyan}DiceWallet for $ac_name already exists {$myaddress}! See ~/wallets/.${ac_name}_dicewallet for details${col_default}"
		fi	
		result=$(echo $dice_addrInfo | jq -r '.result')
		DiceCCaddress=$(echo $dice_addrInfo | jq -r '.DiceCCaddress')
		myCCaddress=$(echo $dice_addrInfo | jq -r '.myCCaddress')
		CCaddress=$(echo $dice_addrInfo | jq -r '.CCaddress')
		Dicemarker=$(echo $dice_addrInfo | jq -r '.Dicemarker')

		if [[ $(cat ~/wallets/.${ac_name}_wallet | grep $myaddress) == "" ]]; then
			echo -e "${col_cyan}Storing your DiceWallet address $myaddress for $ac_name in  ~/wallets/.${ac_name}_wallet${col_default}"


			privkey=$(komodo-cli -ac_name=${ac_name} dumpprivkey $myaddress)
			pubkey=$(komodo-cli -ac_name=${ac_name} validateaddress $myaddress | jq -r '.pubkey')


			echo { \"chain\":\"${ac_name}\", >> ~/wallets/.${ac_name}_wallet
			echo \"addr\":\"${myaddress}\", >> ~/wallets/.${ac_name}_wallet
			echo \"pk\":\"${privkey}\", >> ~/wallets/.${ac_name}_wallet
			echo \"pub\":\"${pubkey}\" } >> ~/wallets/.${ac_name}_wallet
			echo $(cat ~/wallets/.${ac_name}_wallet | sed 's/[][]//g') > ~/wallets/.${ac_name}_wallet 
			echo $(cat ~/wallets/.${ac_name}_wallet | tr -d '\n') > ~/wallets/.${ac_name}_wallet
			echo $(cat ~/wallets/.${ac_name}_wallet | sed 's/} {/},\n{/g') > ~/wallets/.${ac_name}_wallet
			echo \[$(cat ~/wallets/.${ac_name}_wallet)\] > ~/wallets/.${ac_name}_wallet
			echo $(cat ~/wallets/.${ac_name}_wallet | sed '/},/{G;}') > ~/wallets/.${ac_name}_wallet
		fi

		# use pub key from dice address in your wallet
		pubkey=$(komodo-cli -ac_name=${ac_name} validateaddress $myaddress | jq -r '.pubkey')
		balance=$(komodo-cli -ac_name=$ac_name getbalance)
		echo -e "===== ${col_magenta} You have $balance $ac_name to bet using pubkey $pubkey ====="
		rollDice $ac_name &
	fi
done
