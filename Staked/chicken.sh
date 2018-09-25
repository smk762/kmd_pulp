#!/bin/bash

# This script creates transactions to quickly migrate your balance evenly across all active chains on the same -ac_cc id
total_balance=0
num_migrates=0
spread=5
sources=()
targets=()
address_list=()
col_red="\e[31m"
col_green="\e[32m"
col_yellow="\e[33m"
col_blue="\e[34m"
col_magenta="\e[35m"
col_cyan="\e[36m"
col_default="\e[39m"
colors=($col_red $col_green $col_yellow $col_blue $col_magenta $col_cyan)
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
  src_balance=$(echo $($cli_source getbalance))
  tgt_balance=$(echo $($cli_target getbalance))
  echo "[$source] : $src_balance"
  echo "[$target] : $tgt_balance"
}

migrate() {
	local source=$1
	local target=$2
	local amount=$3
	local address="$4"
	local color="$5"
	local progress="$6"
	local cli_source="komodo-cli -ac_name=$source"
	local cli_target="komodo-cli -ac_name=$target"
		migration_ID=$(echo -e "$color[$source -- ($amount) --> $target ($count/$spread)) { $address }]: $col_default ")
	  	pending_migrations=$(echo $pending_migrations+1|bc)
		num_migrates=$(echo $num_migrates+1|bc)
		echo -e " \e[1m\e[96m**** Starting Migration $migration_ID \e[96m************************************\e[39m\e[0m"
		echo -e "$migration_ID Sending to address $address at $(date) ****"
		migrate_start=$SECONDS

				
		# Check if export transaction was created sucessfully
		
		while [[ $txidsize != "64" ]]; do
			echo "$migration_ID Step 1: Creating raw transaction at $(date)"
			txraw=$($cli_source createrawtransaction "[]" "{\"$address\":$3}")
			echo -e "$migration_ID \e[90m$txraw\e[39m"

			echo "$migration_ID Step 2: Creating migrate_converttoexport at $(date)"
			exportData=$($cli_source migrate_converttoexport $txraw $target $3)
			echo -e "$migration_ID \e[90m$exportData\e[39m"

			exportTx=$(echo $exportData | jq -r .exportTx)
			#echo "$migration_ID [exportTx] = $exportTx"
			payouts=$(echo $exportData | jq -r .payouts)
			#echo -e "$migration_ID [payouts] = $payouts${col_default}"
			
			echo "$migration_ID Step 3: Funding raw transaction at $(date)"
			exportFundedData=$($cli_source fundrawtransaction $exportTx)
			echo -e "$migration_ID \e[90m$exportFundedData\e[39m"		
			exportFundedHex=$(echo $exportFundedData | jq -r .hex)

			echo "$migration_ID Step 4: Signing raw transaction at $(date)"
			signedhex=$(echo $($cli_source signrawtransaction $exportFundedHex | jq -r .hex))
			echo -e "$migration_ID \e[90m$signedhex\e[39m"		


			echo "$migration_ID Step 5: Sending raw transaction on at $(date)"
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
		waitforconfirm "$sentTX" "$cli_source"
		echo -e "$migration_ID Step 6: Confirmed export $sentTX at $(date)${col_default}"

		# 6. Use migrate_createimporttransaction to create the import TX
		created=0
		while [[ ${created} -eq 0 ]]; do
			sleep 60
			importTX=$(echo $($cli_source migrate_createimporttransaction $signedhex $payouts) 2> /dev/null)
			if [[ ${importTX} != "" ]]; then
			  created=1
			  echo "$migration_ID Step 7: Created migration import tx at $(date)"
			  echo -e "$migration_ID \e[90m$importTX\e[39m"		
			fi
		done
		#echo "$migration_ID komodo-cli migrate_completeimporttransaction $importTX"

		# 8. Use migrate_completeimporttransaction on KMD to complete the import tx
		created=0
		while [[ $created -eq 0 ]]; do
			sleep 60
			echo "$migration_ID Step 8: Completing import transaction on [KMD] at $(date)"
			completeTX=$(echo $(komodo-cli migrate_completeimporttransaction $importTX) 2> /dev/null)
			if [[ $completeTX != "" ]]; then
			  created=1
				echo "Completed import transaction on [KMD]"
				echo -e "$migration_ID \e[90m$importTX\e[39m"		
			fi
		done
		echo -e "$migration_ID Sign import transaction on KMD complete at $(date)!${col_default}"
		#echo "$migration_ID $cli_target sendrawtransaction $completeTX"

		# 9. Broadcast tx to target chain
		sent=0
		tries=0
		while [[ $sent -eq 0 ]]; do
			echo -e "$migration_ID \e[90m[completeTX] $completeTX\e[39m"
			echo "Sending raw transaction to [$target]"
			sent_iTX=$(echo $($cli_target sendrawtransaction $completeTX) 2> /dev/null)
			echo "$migration_ID Step 9: Broadcasting migration at $(date)"
			sleep 60
			if [[ ${#sent_iTX} = "64" ]]; then
			  	sent=1
				echo "Sent raw transaction to [$target]"
				echo -e "$migration_ID \e[90m$sent_iTX\e[39m"		
			elif [[ $sent_iTX != "" ]]; then
				echo -e "\e[91m------------------------------------------------------------"
				echo "$migration_ID Invalid txid returned from send import transacton at $(date)"
				echo "$sent_iTX"
				echo "$completeTX"
				echo -e "-------------------------------------------------------------${col_default}"
				break
			else
			  tries=$(( $tries +1 ))
			  echo "Raw transaction to [$target] not ready, attempt $tries / 90"
			  if [[ $tries -ge 90 ]]; then
			  echo -e "\e[91m------------------------------------------------------------"
			    echo "$migration_ID Failed Import TX at $(date)"
			    echo "Exiting after 90 tries: $completeTX"
			    echo "From Chain: $1"
			    echo "Export TX: $sentTX"
			    echo "$signedhex $payouts"
			  	echo -e "-------------------------------------------------------------${col_default}"
			    exit
			  fi
			fi
		done

		waitforconfirm "$sent_iTX" "$cli_target"
		echo -e "$migration_ID Confirmed import $sent_iTX at $(date)${col_default}"
		migrate_duration=$(echo $SECONDS/60-$migrate_start/60|bc)
		echo -e "\e[95m================== $migration_ID MIGRATION COMPLETED in $migrate_duration minutes ===================="
		printbalance
		echo -e "============================================================================================================${col_default}"
}

migratePair() {	
	local source=$1
	local target=$2
	local color=$3
	local amount=$4
	# Alias for running cli
	cli_source="komodo-cli -ac_name=$source"
	cli_target="komodo-cli -ac_name=$target"
	addresses=$($(echo komodo-cli -ac_name=$target listaddressgroupings))	
	num_addr=$(echo $addresses | jq '.[] | length')
	count=1
	for address in $(echo "${addresses}" | jq -c -r '.[][][0]'); do
		progress="$count/$spread"
		migration_ID=$(echo -e "$color[$source -- ($amount) --> $target ($progress)) { $address }]: $col_default ")
		#echo "$migration_ID Creating TX $count/$spread"
		target_balance="$($cli_target getbalance)"
		underbalance=$(printf '%.0f' $(echo $target_balance-$average|bc))
		migrate $source $target $amount $address $color &
		sleep 120
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
  balance="$(printf '%.0f' $(komodo-cli -ac_name=$chain getbalance))"
  total_balance=$(echo $balance+$total_balance|bc)
  if [ $balance -lt $min ]; then
  	min=$(printf '%.0f' $(echo $balance))
  fi
  if [  $balance -gt $max ]; then
	max=$(printf '%.0f' $(echo $balance))
  fi
done
range=$(echo $max-$min|bc)
average=$(echo $total_balance/$num_chains|bc)

for chain in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
	sources+=($chain)
	targets+=($chain)
done
echo -e "\e[92m[TOTAL BALANCE :  ${total_balance}]${col_default}"
echo -e "\e[92m[Average balance = ${average}]${col_default}"
echo -e "\e[92m[Min balance = ${min}]${col_default}"
echo -e "\e[92m[Max balance = ${max}]${col_default}"
echo -e "\e[92m[Range = ${range}]${col_default}"

echo "=============================="
update_range &
colorIndex=0
for source in ${sources[@]}; do
  script_start=$SECONDS
  for target in ${targets[@]}; do
  	pairColor=${colors[${colorIndex}]}
  	migratePair $source $target $pairColor 10 &
  	colorIndex=$(echo $colorIndex+1|bc)
  	if [ $colorIndex -ge ${#colors[@]} ]; then
  		colorIndex=0;
  	fi
  done
done


script_duration=$(echo $SECONDS/60-$script_start/60|bc)
echo -e "\e[95m"
#echo "================== EQUALISATION COMPLETED! ${num_migrates} migrations in $script_duration minutes ====================";
echo -e "${col_default}"
for chain in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
  balance="$(komodo-cli -ac_name=$chain getbalance)"
  echo "$chain balance = $(echo $balance)"
  total_balance=$(echo $balance+$total_balance|bc)
done
