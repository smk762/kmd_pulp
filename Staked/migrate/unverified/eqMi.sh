#!/bin/bash

# This script creates transactions to quickly migrate your balance evenly across all active chains on the same -ac_cc id
total_balance=0
export num_migrates=0
spread=2
count=1
sources=()
targets=()
address_list=()
export pending_migrations=0
export complete_migrations=0
col_red="\e[31m"
col_green="\e[32m"
col_yellow="\e[33m"
col_blue="\e[34m"
col_magenta="\e[35m"
col_cyan="\e[36m"
col_default="\e[39m"
colors=($col_red $col_green $col_yellow $col_blue $col_magenta $col_cyan)
export fail_at_9=0
# function to delay next step until last transaction has been confirmed. Takes 2 params, $1 is transaction hash, $2 is chain name

longestchain () {
  chain=$1
  if [[ $chain == "KMD" ]]; then
    chain=""
  fi
  tries=0
  longestchain=0
  while [[ $longestchain -eq 0 ]]; do
    info=$(komodo-cli -ac_name=$chain getinfo)
    longestchain=$(echo ${info} | jq -r '.longestchain')
    tries=$(( $tries +1 ))
    if (( $tries > 60)); then
      echo "0"
      return 0
    fi
    sleep 1
  done
  echo $longestchain
  return 1
}

checksync () {
  chain=$1
  if [[ $chain == "KMD" ]]; then
    chain=""
  fi
  lc=$(longestchain $1)
  if [[ $lc = "0" ]]; then
    connections=$(komodo-cli -ac_name=$chain getinfo | jq -r .connections)
    if [[ $connections = "0" ]]; then
      echo -e "\033[1;31m  [$1] ABORTING - $1 has no network connections, Help Human! \033[0m"
      komodo-cli -ac_name=$chain stop
      return 0
    else
      lc=$(longestchain $1)
    fi
  fi
  if [[ $lc = "0" ]]; then
    blocks=$(komodo-cli -ac_name=$chain getblockcount)
    tries=0
    while (( $blocks < 128 )) && (( $tries < 90 )); do
      echo "[$1] $blocks blocks"
      blocks=$(komodo-cli -ac_name=$chain getblockcount)
      tries=$(( $tries +1 ))
      lc=$(longestchain $1)
      if (( $blocks = $lc )); then
        echo "[$1] Synced on block: $lc"
        return 1
      fi
    done
    if (( blocks = 0 )) && (( lc = 0 )); then
      # this chain is just not syncing even though it has network connections we will stop its deamon and abort for now. Myabe next time it will work.
      komodo-cli -ac_name=$chain stop
      echo -e "\033[1;31m  [$1] ABORTING no blocks or longest chain found, Help Human! \033[0m"
      return 0
    elif (( blocks = 0 )) && (( lc != 0 )); then
      # This chain has connections and knows longest chain, but will not sync, we will kill it. Maybe next time it will work.
      echo -e "\033[1;31m [$1] ABORTING - No blocks synced of $lc. Help Human! \033[0m"
      komodo-cli -ac_name=$chain stop
      return 0
    elif (( blocks > 128 )) && (( lc = 0 )); then
      # This chain is syncing but does not have longest chain. Myabe next time the prcess runs it will work, so we will leave it running but not add it to iguana.
      echo -e "\033[1;31m [$1] ABORTING - Synced to $blocks, but no longest chain is found. Help Human! \033[0m"
      return 0
    fi
  fi
  blocks=$(komodo-cli -ac_name=$chain getblockcount)
  while (( $blocks < $lc )); do
    sleep 60
    lc=$(longestchain $1)
    blocks=$(komodo-cli -ac_name=$chain getblockcount)
    progress=$(echo "scale=3;$blocks/$lc" | bc -l)
    echo "[$1] $(echo $progress*100|bc)% $blocks of $lc"
  done
  echo "[$1] Synced on block: $lc"
  return 1
}

daemon_stopped () {
  stopped=0
  while [[ ${stopped} -eq 0 ]]; do
    pgrep -af "$1" > /dev/null 2>&1
    outcome=$(echo $?)
    if [[ ${outcome} -ne 0 ]]; then
      stopped=1
    fi
    sleep 2
  done
}


waitforconfirm () {
  confirmations=0
  while [[ ${confirmations} -lt 1 ]]; do
    sleep 3
    confirmations=$($2 gettransaction $1 | jq -r .confirmations)
    # Keep re-broadcasting
    $2 sendrawtransaction $($2 getrawtransaction $1) > /dev/null 2>&1
  done
}


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

printbalance () {
  src_balance=$(echo $($cli_source getbalance))
  tgt_balance=$(echo $($cli_target getbalance))
  echo "[$source] : $src_balance"
  echo "[$target] : $tgt_balance"
}

update_range() {
	now_range=0
	while [ $now_range -gt 10 ]; do
		now_min=99999999
		now_max=0
		for chain in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
	  	  balance="$(printf '%.0f' $(komodo-cli -ac_name=$chain getbalance))"
		  if [ $balance -lt $now_min ]; then
		  	now_min=$balance
		  fi
		  if [  $balance -gt $now_max ]; then
			now_max=$balance
		  fi
		done
		now_range=$(echo $max-$min|bc)
		if [ $now_range -lt 10 ]; then
			echo "Balances range is less than  10, script complete."
			exit 0;
		else
			echo "Balances range is less than  ${now_range}."
		fi
		sleep 300
	done
}

update_range &

migrate() {
	source=$1
	target=$2
	addresses=$3
	color=$4
	# Alias for running cli
	cli_source="komodo-cli -ac_name=$source"
	cli_target="komodo-cli -ac_name=$target"
	balance="$($cli_source getbalance)"
	overbalance=$(printf "%.0f" $(echo $balance-$average|bc))
	target_balance="$($cli_target getbalance)"
	underbalance=$(printf '%.0f' $(echo $target_balance-$average|bc))
	diff=$(echo $overbalance+$underbalance|bc)
	if [ $diff -lt 0 ]; then
		send_sum=$overbalance
	else
		send_sum=${underbalance#-}
	fi
	echo "Addresses for $target : ${addresses[@]}"
	amount=$(printf "%.0f" $(echo $send_sum/$spread|bc))
	if [ $amount -lt 5 ]; then
		amount=5;
	fi
	if [ $amount -gt $overbalance ]; then
		amount=$overbalance;
	fi
	source_index=0
	target_index=0
	for i in "${targets[@]}"; do
	    if [[ ${targets[$i]} == $target ]]; then
	    	break
	    fi
		target_index=$(echo $target_index+1|bc);
	done

	for i in "${sources[@]}"; do
	    if [[ ${sources[$i]} == $source ]]; then
	    	break
	    fi
		source_index=$(echo $source_index+1|bc);
	done
	addr_start=$(echo $source_index*5|bc)
	addr_stop=$(echo $addr_start+5|bc)
	echo "Using addresses $addr_start to $addr_stop"
	for (( c=$addr_start; c<=$addr_stop; c++ )); do
		pending_migrations=$(echo $pending_migrations+1|bc)
		address=${addresses[$c]}
		
		if [ $overbalance -lt 5 ]; then
			break 
		fi
		progress="$count/$spread"
		if [ $count -lt $spread ]; then
			migration_ID=$(echo -e "$color[$source -- ($amount) --> $target ($progress) { $address }]: $col_default ")
			#echo "$migration_ID Creating TX $count/$spread"
		    target_balance="$($cli_target getbalance)"
		    underbalance=$(printf '%.0f' $(echo $target_balance-$average|bc))
		    if [ ${underbalance#-} -lt 10 ]; then
		    	echo -e "$migration_ID \e[93mTarget balance ($target_balance) within 10 of average ($average), starting equalisation of next pair.${col_default}"
		    	break
		    else
				num_migrates=$(echo $num_migrates+1|bc)
				echo -e " \e[1m\e[96m**** Starting Migration $migration_ID \e[96m************************************\e[39m\e[0m"
				echo "$pending_migrations migrations pending"
				echo -e "$migration_ID Sending to address $address at $(date) ****"
				migrate_start=$SECONDS

						
				# Check if export transaction was created sucessfully
				
				while [[ $txidsize != "64" ]]; do
					echo "$migration_ID Step 1: Creating raw transaction at $(date)"
					txraw=$($cli_source createrawtransaction "[]" "{\"$address\":$amount}")
					#echo -e "$migration_ID \e[90m$txraw\e[39m"

					echo "$migration_ID Step 2: Creating migrate_converttoexport at $(date)"
					exportData=$($cli_source migrate_converttoexport $txraw $target $amount)
					#echo -e "$migration_ID \e[90m$exportData\e[39m"

					exportTx=$(echo $exportData | jq -r .exportTx)
					#echo "$migration_ID [exportTx] = $exportTx"
					payouts=$(echo $exportData | jq -r .payouts)
					#echo -e "$migration_ID [payouts] = $payouts${col_default}"
					
					echo "$migration_ID Step 3: Funding raw transaction at $(date)"
					exportFundedData=$($cli_source fundrawtransaction $exportTx)
					#echo -e "$migration_ID \e[90m$exportFundedData\e[39m"		
					exportFundedHex=$(echo $exportFundedData | jq -r .hex)

					echo "$migration_ID Step 4: Signing raw transaction at $(date)"
					signedhex=$(echo $($cli_source signrawtransaction $exportFundedHex | jq -r .hex))
					#echo -e "$migration_ID \e[90m$signedhex\e[39m"		


					migrate_duration=$(echo $SECONDS/60-$migrate_start/60|bc)
					echo "$migration_ID Step 5: Sending raw transaction at $(date) ($migrate_duration min)"
					sentTX=$($cli_source sendrawtransaction "$signedhex")
					echo -e "$migration_ID \e[90m$sentTX\e[39m"
					txidsize=${#sentTX}
					sleep 60
					if [[ $txidsize != "64" ]]; then
						echo -e "$migration_ID \e[91mExport TX not sucessfully created at $(date). Trying again in 60 seconds."
						echo -e "$migration_ID \e[90m[SENT TX] = $sentTX"
						echo -e "$migration_ID \e[90m[SIGNED HEX] = $signedhex${col_default}"
					fi
				done

				# 5. Wait for a confirmation on source chain.
				# waitforconfirm "$sentTX" "$cli_source"
				migrate_duration=$(echo $SECONDS/60-$migrate_start/60|bc)
				echo -e "$migration_ID Step 6: Confirmed export $sentTX at $(date) ($migrate_duration min)${col_default}"

				# 6. Use migrate_createimporttransaction to create the import TX
				created=0
				while [[ ${created} -eq 0 ]]; do
					sleep 60
					importTX=$(echo $($cli_source migrate_createimporttransaction $signedhex $payouts) 2> /dev/null)
					if [[ ${importTX} != "" ]]; then
						created=1
						migrate_duration=$(echo $SECONDS/60-$migrate_start/60|bc)
						echo "$migration_ID Step 7: Created migration import tx at $(date) ($migrate_duration min)"
					#	echo -e "$migration_ID \e[90m$importTX\e[39m"		
					fi
				done
				#echo "$migration_ID komodo-cli migrate_completeimporttransaction $importTX"

				# 8. Use migrate_completeimporttransaction on KMD to complete the import tx
				created=0
				while [[ $created -eq 0 ]]; do
					sleep 60
					migrate_duration=$(echo $SECONDS/60-$migrate_start/60|bc)
					echo "$migration_ID Step 8: Completing import transaction on [KMD] at $(date) ($migrate_duration min)"
					completeTX=$(echo $(komodo-cli migrate_completeimporttransaction $importTX) 2> /dev/null)
					if [[ $completeTX != "" ]]; then
					  created=1
						echo "$migration_ID Completed import transaction on [KMD]"
						echo -e "$migration_ID \e[90m$importTX\e[39m"		
					fi
				done
				echo -e "$migration_ID Sign import transaction on KMD complete at $(date) ($migrate_duration min)!${col_default}"
				#echo "$migration_ID $cli_target sendrawtransaction $completeTX"

				# 9. Broadcast tx to target chain
				sent=0
				tries=0
				while [[ $sent -eq 0 ]]; do
					echo -e "$migration_ID \e[90m[completeTX] $completeTX\e[39m"
					echo "$migration_ID Sending raw transaction"
					sent_iTX=$(echo $($cli_target sendrawtransaction $completeTX) 2> /dev/null)
					migrate_duration=$(echo $SECONDS/60-$migrate_start/60|bc)
					echo "$migration_ID Step 9: Broadcasting migration at $(date) ($migrate_duration min)"
					echo "sent_iTX # : ${#sent_iTX}"
					sleep 60
					if [[ ${#sent_iTX} = "64" ]]; then
					  	sent=1
						echo "$migration_ID Sent raw transaction"
						echo -e "$migration_ID \e[90m$sent_iTX\e[39m"		
					elif [[ $sent_iTX != "" ]]; then
						echo -e "\e[91m------------------------------------------------------------"
						echo "$migration_ID Invalid txid returned from send import transacton at $(date) ($migrate_duration min)"
						echo "$sent_iTX"
						echo "$completeTX"
						echo -e "-------------------------------------------------------------${col_default}"
						break
					else
						tries=$(( $tries +1 ))
						echo "$migration_ID Raw transaction not ready, attempt $tries / 90"
						if [[ $tries -ge 90 ]]; then
							fail_at_9=$(echo $fail_at_9+1|bc)
							echo -e "\e[91m------------------------------------------------------------"
						    echo "$migration_ID Failed Import TX at $(date) ($migrate_duration min) Fail count: $fail_at_9."
						    echo "Exiting after 90 tries: $completeTX"
						    echo "From Chain: $source"
						    echo "Export TX: $sentTX"
						    echo "$signedhex $payouts"
						  	echo -e "-------------------------------------------------------------${col_default}"
						    exit
						fi
					fi
				done

				# waitforconfirm "$sent_iTX" "$cli_target"
				echo -e "$migration_ID Confirmed import $sent_iTX at $(date)${col_default}"
				migrate_duration=$(echo $SECONDS/60-$migrate_start/60|bc)
				echo -e "\e[95m================== $migration_ID MIGRATION COMPLETED in $migrate_duration minutes ===================="
				printbalance
				echo -e "============================================================================================================${col_default}"
			  	complete_migrations=$(echo $complete_migrations+1|bc)
				echo "$complete_migrations / $pending_migrations migrations complete. Fail count: $fail_at_9. Count: $count"
		  		sleep 120
			fi
		fi
		count=$(echo $count+1|bc)
  	done		
}


echo -e "\e[92m====== STAKED BALANCES ======${col_default}"
# use https://github.com/smk762/kmd_pulp/blob/master/Staked/staked-cli and link to /usr/local/bin
#staked-cli getbalance    # like assets-cli, but for all chains listed in assetchains.json

# Get latest chain parameters
ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
num_chains=$(echo "${ac_json}" | jq  -r '. | length');


# Get total balance accross all chains
min=99999999999
max=0
for chain in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
	checksync $chain
	balance="$(komodo-cli -ac_name=$chain getbalance)"
	if [ $balance -lt $min ]; then
		min=$(printf '%.0f' $(echo $balance))
	fi
	if [  $balance -gt $max ]; then
	max=$(printf '%.0f' $(echo $balance))
	fi
  	total_balance=$(echo $balance+$total_balance|bc)
	delta=$(printf '%.0f' $(echo $balance-$average|bc))
	if [ $delta -gt 0 ]; then
		echo -e "$chain balance = $(echo $balance)\e[94m (Adding to sources) - $delta coins to spare. ${col_default}"
		sources+=($chain)
	else
		echo -e "$chain balance = $(echo $balance)\e[93m (Adding to targets) - needs ${delta#-} coins. ${col_default}"
		targets+=($chain)
	fi
done
range=$(echo $max-$min|bc)
average=$(echo $total_balance/$num_chains|bc)
echo -e "\e[92m[TOTAL BALANCE :  ${total_balance}]${col_default}"
echo -e "\e[92m[Average balance = ${average}]${col_default}"
echo -e "\e[92m[Min balance = ${min}]${col_default}"
echo -e "\e[92m[Max balance = ${max}]${col_default}"
echo -e "\e[92m[Range = ${range}]${col_default}"

echo "=============================="

for target in ${targets[@]}; do
	addresses=()
	address_req=$(echo ${#targets[@]}*$spread|bc)
	echo "$address_req addresses required on target"
	num_addr=$(komodo-cli -ac_name=${target} listaddressgroupings | jq -r '. | length')
	if [ -z "$num_addr" ]; then
		num_addr=0
	fi
	if [ ${num_addr} -lt ${address_req} ]; then 
		echo -e "\e[91m WARNING: You have $num_addr active addresses on $target. Need $address_req active addresses for ${target}."
		echo " This script creates an addresses to be used for cross chain coin migration."
		echo " The address, privkey, and pubkey are stored in a owner read-only file"
		echo -e "Make sure to encrypt, backup, or delete as required \e[39m"
		#prompt_confirm "Create new addresses for ${target}? (exit and ask in Discord if unsure)" || exit 0
		if [ ! -d ~/wallets  ]; then
			mkdir ~/wallets
		fi
		if [ ! -d ~/.komodo/${target}  ]; then
			echo -e "\e[91m [ $target ] CONF FILE DOES NOT EXIST!"
	                echo -e "Sync the chains first! \e[39m"
			exit 1
		fi
		if [ ! -f  ~/wallets/.${target}_wallet ]; then
			touch  ~/wallets/.${target}_wallet
			sudo chmod 600  ~/wallets/.${target}_wallet
		fi
		for (( c=1; c<=$address_req; c++ )); do
			address=$(komodo-cli -ac_name=$target getnewaddress)
			echo "Created $address for [ $target ]"
			echo { \"chain\":\"${target}\", >> ~/wallets/.${target}_wallet
			echo \"addr\":\"${address}\", >> ~/wallets/.${target}_wallet
			echo \"pk\":\"$(komodo-cli -ac_name=${target} dumpprivkey $address)\", >> ~/wallets/.${target}_wallet
			echo \"pub\":\"$(komodo-cli -ac_name=${target} validateaddress $address | jq -r '.pubkey')\" } >> ~/wallets/.${target}_wallet
			addresses+=($address)
		done
		echo -e "\e[92m Finished: Your new address information is located in ~/wallets \e[39m"
		sleep 10
	else
		first_addr=$(komodo-cli -ac_name=$target listaddressgroupings | jq -r '.[][0][0]')
		addr_list="$(komodo-cli -ac_name=$target listaddressgroupings | jq -r '.[][][0]')"

		addresses=()
		addr_count=0
		
		for addr in ${addr_list[@]}; do
			if [ $addr_count -ge $address_req ]; then
				break
			else 
				addresses+=($addr)
				addr_count=$(( $addr_count +1 ))
			fi
		done
	fi
	colorIndex=0
	for source in ${sources[@]}; do
  		pairColor=${colors[${colorIndex}]}
	  	script_start=$SECONDS
	  	migrate $source $target $addresses $pairColor
	  	colorIndex=$(echo $colorIndex+1|bc)
	  	if [ $colorIndex -ge ${#colors[@]} ]; then
	  		colorIndex=0;
	  	fi
	done
done

script_duration=$(echo $SECONDS/60-$script_start/60|bc)
for chain in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
  balance="$(komodo-cli -ac_name=$chain getbalance)"
  echo "$chain balance = $(echo $balance)"
  total_balance=$(echo $balance+$total_balance|bc)
done
