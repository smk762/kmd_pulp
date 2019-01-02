#!/bin/bash

# This script creates transactions to quickly migrate your balance evenly across all active chains on the same -ac_cc id
total_balance=0
num_migrates=0
spread=5
sources=()
targets=()
address_list=()

# function to delay next step until last transavtion has been confirmed. Takes 2 params, $1 is transaction hash, $2 is chain name
waitforconfirm () {
  confirmations=0
  while [[ ${confirmations} -lt 1 ]]; do
    sleep 3
    confirmations=$($2 gettransaction $1 | jq -r .confirmations)
    # Keep re-broadcasting
    $2 sendrawtransaction $($2 getrawtransaction $1) > /dev/null 2>&1
  done
}

printbalance () {
  src_balance=`$cli_source getbalance`
  tgt_balance=`$cli_target getbalance`
  echo "[$source] : $src_balance"
  echo "[$target] : $tgt_balance"
}

echo -e "\e[92m====== STAKED BALANCES ======\e[39m"
# use https://github.com/smk762/kmd_pulp/blob/master/Staked/staked-cli and link to /usr/local/bin
#staked-cli getbalance    # like assets-cli, but for all chains listed in assetchains.json

# Get latest chain parameters
ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
num_chains=$(echo "${ac_json}" | jq  -r '. | length');

# Get total balance accross all chains

for chain in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
  balance="$(komodo-cli -ac_name=$chain getbalance)"
  total_balance=$(echo $balance+$total_balance|bc)
done

average=$(echo $total_balance/$num_chains|bc)

for chain in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
	balance="$(komodo-cli -ac_name=$chain getbalance)"
	delta=$(printf '%.0f' $(echo $balance-$average|bc))
	if [ $delta -gt 0 ]; then
		echo -e "$chain balance = $(echo $balance)\e[94m (Adding to sources)\e[39m"
		sources+=($chain)
	else
		echo -e "$chain balance = $(echo $balance)\e[93m (Adding to targets)\e[39m"
		targets+=($chain)
	fi
done
echo -e "\e[92m[TOTAL BALANCE :  ${total_balance}]\e[39m"
echo -e "\e[92m[Average balance = ${average}]\e[39m"

echo "=============================="
# Get balance deltas
for source in ${sources[@]}; do
  script_start=$SECONDS

  for target in ${targets[@]}; do
    # Alias for running cli
    cli_target="komodo-cli -ac_name=$target"
    cli_source="komodo-cli -ac_name=$source"
    balance="$($cli_source getbalance)"
    overbalance=$(printf "%.0f" $(echo $balance-$average|bc))
    echo -e "\e[95m$source has $overbalance spare coins\e[39m"
    target_balance="$($cli_target getbalance)"
    underbalance=$(printf '%.0f' $(echo $target_balance-$average|bc))
    echo -e "\e[95m$target needs ${underbalance#-} coins\e[39m"
    diff=$(echo $overbalance+$underbalance|bc)
    if [ $diff -lt 0 ]; then
      send_sum=$overbalance
    else
      send_sum=${underbalance#-}
    fi
    addresses=$($(echo komodo-cli -ac_name=$target listaddressgroupings))
    num_addr=$(echo $addresses | jq '.[] | length')
    echo -e "\e[94m$num_addr addresses at target $target\e[39m"

    for address in $(echo "${addresses}" | jq -c -r '.[][][0]'); do
    	if [ $num_addr -lt $spread ]; then 
    		spread=$num_addr
    	fi 
		amount=$(printf "%.0f" $(echo $send_sum/$spread|bc))

		if [ $amount -lt 5 ]; then
			amount=5;
		fi

	    target_balance="$($cli_target getbalance)"
	    underbalance=$(printf '%.0f' $(echo $target_balance-$average|bc))

	    if [ ${underbalance#-} -lt 10 ]; then
	    	echo -e "\e[93m"
	    	echo "$target balance within 10 of average ($average), starting equalisation of next pair."
	    	echo -e "\e[39m"
	    	break
	    else
			num_migrates=$(echo $num_migrates+1|bc)
			echo -e "\e[96m"
			echo "**** Starting Migration #${num_migrates} ************************************"
			echo -e "\e[32m"
			echo "**** Sending $amount from $source to $target address $address at $(date) ****"
			echo -e "\e[39m"
			migrate_start=$SECONDS
			# Raw tx that we will work with
			txraw=`$cli_source createrawtransaction "[]" "{\"$address\":$amount}"`
			#echo "[RAW TRANSACTION HEX] = $txraw"
			# Convert to an export tx
			exportData=`$cli_source migrate_converttoexport $txraw $target $amount`
			#echo "[MIGRATE EXPORT DATA] = $exportData"
			exportRaw=`echo $exportData | jq -r .exportTx`
			# Fund it
			exportFundedData=`$cli_source fundrawtransaction $exportRaw`
			exportFundedTx=`echo $exportFundedData | jq -r .hex`
			payouts=`echo $exportData | jq -r .payouts`

			# 4. Sign rawtx and export
			signedhex=`$cli_source signrawtransaction $exportFundedTx | jq -r .hex`
			#echo "[SIGNED HEX] = $signedhex"
			sentTX=`$cli_source sendrawtransaction $signedhex`
			#echo "[SENT TX] = $sentTX"

			# Check if export transaction was created sucessfully
			txidsize=${#sentTX}
			if [[ $txidsize != "64" ]]; then
				echo -e "\e[91m"
				echo "Export TX not sucessfully created at $(date)"
				echo -e "\e[39m"
				echo "$sentTX"
				echo "$signedhex"
				exit
			fi

			# 5. Wait for a confirmation on source chain.
			waitforconfirm "$sentTX" "$cli_source"
			echo -e "\e[32m"
			echo "[$source] : Confirmed export $sentTX at $(date)"
			echo -e "\e[39m"
			#echo "$cli_source migrate_createimporttransaction $signedhex $payouts"

			# 6. Use migrate_createimporttransaction to create the import TX
			created=0
			while [[ ${created} -eq 0 ]]; do
				sleep 60
				importTX=`$cli_source migrate_createimporttransaction $signedhex $payouts 2> /dev/null`
				if [[ ${importTX} != "" ]]; then
				  created=1
				  # echo "[IMPORT TX] = $importTX"
				fi
			done
			echo -e "\e[32m"
			echo "Create import transaction sucessful at $(date)!"
			echo -e "\e[39m"
			#echo "komodo-cli migrate_completeimporttransaction $importTX"

			# 8. Use migrate_completeimporttransaction on KMD to complete the import tx
			created=0
			while [[ $created -eq 0 ]]; do
				sleep 60
				completeTX=`komodo-cli migrate_completeimporttransaction $importTX 2> /dev/null`
				if [[ $completeTX != "" ]]; then
				  created=1
				fi
			done
			echo -e "\e[32m"
			echo "Sign import transaction on KMD complete at $(date)!"
			echo -e "\e[39m"
			#echo "$cli_target sendrawtransaction $completeTX"

			# 9. Broadcast tx to target chain
			sent=0
			tries=0
			while [[ $sent -eq 0 ]]; do
				sleep 60
				sent_iTX=`$cli_target sendrawtransaction $completeTX 2> /dev/null`
				if [[ ${#sent_iTX} = "64" ]]; then
				  sent=1
				elif [[ $sent_iTX != "" ]]; then
				  echo -e "\e[91m"
				  echo "------------------------------------------------------------"
				  echo "Invalid txid returned from send import transacton"
				  echo "$sent_iTX"
				  echo "$completeTX"
				  echo "-------------------------------------------------------------"
				  echo -e "\e[39m"
				  exit
				else
				  tries=$(( $tries +1 ))
				  if [[ $tries -ge 90 ]]; then
				  	echo -e "\e[91m"
				    echo "------------------------------------------------------------"
				    echo "Failed Import TX on $target at $(date)"
				    echo "Exiting after 90 tries: $completeTX"
				    echo "From Chain: $source"
				    echo "Export TX: $sentTX"
				    echo "$signedhex $payouts"
				    echo "------------------------------------------------------------"
				    echo -e "\e[39m"
				    exit
				  fi
				fi
			done

			waitforconfirm "$sent_iTX" "$cli_target"
			echo -e "\e[32m"
			echo "[$target] : Confirmed import $sent_iTX at $(date)"
			echo -e "\e[39m"
			printbalance
			migrate_duration=$(echo $SECONDS/60-$migrate_start/60|bc)
			echo -e "\e[95m"
			echo "================== MIGRATION #${num_migrates} COMPLETED in $migrate_duration minutes ====================";
			echo -e "\e[39m"
		fi
	done
	echo $targets
  done
done
script_duration=$(echo $SECONDS/60-$script_start/60|bc)
echo -e "\e[95m"
echo "================== EQUALISATION COMPLETED! ${num_migrates} migrations in $script_duration minutes ====================";
echo -e "\e[39m"
for chain in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
  balance="$(komodo-cli -ac_name=$chain getbalance)"
  echo "$chain balance = $(echo $balance)"
  total_balance=$(echo $balance+$total_balance|bc)
done


