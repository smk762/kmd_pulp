#!/bin/bash

col_red="\e[31m"
col_green="\e[32m"
col_yellow="\e[33m"
col_blue="\e[34m"
col_magenta="\e[35m"
col_cyan="\e[36m"
col_default="\e[39m"
colors=($col_red $col_green $col_yellow $col_blue $col_magenta $col_cyan)
chains=()
sources=()
targets=()
total_balance=0

# Get latest chain parameters
ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
num_chains=$(echo "${ac_json}" | jq  -r '. | length');
for chain in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
  balance=$(komodo-cli -ac_name=$chain getbalance)
  chains+=($chain)
  total_balance=$(echo $balance+$total_balance|bc)
done
average=$(echo $total_balance/$num_chains|bc)

for chain in ${chains[@]}; do
  balance=$(printf '%.0f' $(echo $(komodo-cli -ac_name=$chain getbalance)))
  delta=$(printf '%.0f' $(echo $balance-$average|bc))
  if [ $delta -gt 0 ]; then
    echo -e "$chain balance = $(echo $balance)\e[94m - $delta coins to spare. ${col_default}"
    sources+=($chain)
  else
    echo -e "$chain balance = $(echo $balance)\e[93m - needs ${delta#-} coins. ${col_default}"
    targets+=($chain)
  fi
done

# This script makes the neccesary transactions to migrate
# coin between 2 assetchains on the same -ac_cc id
waitforconfirm () {
  confirmations=0
  while [[ ${confirmations} -lt 1 ]]; do
    sleep 15
    confirmations=$($2 gettransaction $1 | jq -r .confirmations)
    # Keep re-broadcasting
    $2 sendrawtransaction $($2 getrawtransaction $1) > /dev/null 2>&1
  done
}

printbalance () {
  # Get total balance accross all chains
  min=99999999999
  max=0
  echo "============================================================"
  total_balance=0
  for chain in ${chains[@]}; do
    balance=$(printf '%.0f' $(komodo-cli -ac_name=$chain getbalance))
    if [ $balance -lt $min ]; then
      min=$(printf '%.0f' $(echo $balance))
    fi
    if [ $balance -gt $max ]; then
      max=$(printf '%.0f' $(echo $balance))
    fi
    total_balance=$(echo $balance+$total_balance|bc)
  done
  average=$(echo $total_balance/$num_chains|bc)
  range=$(echo $max-$min|bc)
  echo -e "\e[92m[Min: ${min}]${col_default}"
  echo -e "\e[92m[Max: ${max}]${col_default}"
  echo -e "\e[92m[Range: ${range}]${col_default}"
  echo -e "\e[92m[Average: ${Average}]${col_default}"
  echo -e "\e[92m[TOTAL:  ${total_balance}]${col_default}"
  echo "============================================================"
  echo "Sources: ${sources[@]}"
  echo "Targets: ${targets[@]}"
  echo "============================================================"
}

printbalance
amount=1
for target in ${targets[@]}; do
  addresses=()
  addrss=$(komodo-cli -ac_name=${chain} listaddressgroupings | jq -r '.[][][0]')
  for addr in $addrss; do
    addresses+=($addr)
  done
  num_addr=${#addresses[@]}
  if [ -z $num_addr ]; then
    num_addr=0
  fi
  if [ $num_addr -lt $address_req  ]; then
    selected_addr=$addresses
    echo -e "\e[91m WARNING: You have less than $address_req active addresses for ${chain}."
    echo " This script creates an addresses to be used for cross chain coin migration."
    echo " The address, privkey, and pubkey are stored in a owner read-only file"
    echo -e "Make sure to encrypt, backup, or delete as required \e[39m"
    prompt_confirm "Create new addresses for ${chain}? (exit and ask in Discord if unsure)" || exit 0
    if [ ! -d ~/wallets  ]; then
      mkdir ~/wallets
    fi
    if [ ! -d ~/.komodo/${chain}  ]; then
      echo -e "\e[91m [ $chain ] CONF FILE DOES NOT EXIST!"
                  echo -e "Sync the chains first! \e[39m"
      exit 1
    fi
    if [ ! -f  ~/wallets/.${chain}_wallet ]; then
      touch  ~/wallets/.${chain}_wallet
      chmod 600  ~/wallets/.${chain}_wallet
    fi

    for (( i=${#selected_addr[@]}; i<$address_req; i++ )); do
      address=$(komodo-cli -ac_name=$chain getnewaddress)
      echo "Created $address for [ $chain ]"
      echo { \"chain\":\"${chain}\", >> ~/wallets/.${chain}_wallet
      echo \"addr\":\"${address}\", >> ~/wallets/.${chain}_wallet
      echo \"pk\":\"$(komodo-cli -ac_name=${chain} dumpprivkey $address)\", >> ~/wallets/.${chain}_wallet
      echo \"pub\":\"$(komodo-cli -ac_name=${chain} validateaddress $address | jq -r '.pubkey')\" } >> ~/wallets/.${chain}_wallet
      selected_addr+=($address)
    done
    num_addr=${#selected_addr[@]}
    # clean up the json
    echo $(cat ~/wallets/.${chain}_wallet | sed 's/[][]//g') > ~/wallets/.${chain}_wallet 
    echo $(cat ~/wallets/.${chain}_wallet | tr -d '\n') > ~/wallets/.${chain}_wallet
    echo $(cat ~/wallets/.${chain}_wallet | sed 's/} {/},\n{/g') > ~/wallets/.${chain}_wallet
    echo \[$(cat ~/wallets/.${chain}_wallet)\] > ~/wallets/.${chain}_wallet
    echo $(cat ~/wallets/.${chain}_wallet | sed '/},/{G;}') > ~/wallets/.${chain}_wallet
    # cat ~/wallets/.${chain}_wallet
    echo -e "\e[92m Finished: Your address info is located in ~/wallets \e[39m"
  else
    selected_addr=()
    for (( i=0; i<$address_req; i++ )); do
        selected_addr+=(${addresses[${i}]})
    done
  fi
  echo "$chain has $num_addr addresses (${#selected_addr[@]} selected)."
  echo "Selected address list: ${selected_addr[@]}"

  for source in ${sources[@]}; do
      pairColor=${colors[${colorIndex}]}
      script_start=$SECONDS


  migration_ID=$(echo -e "$color[$source -- ($amount) --> $target ($progress) { $address }]: $col_default ")

  # Alias for running cli
  cli_target="komodo-cli -ac_name=$target"
  cli_source="komodo-cli -ac_name=$source"
  src_balance=`$cli_source getbalance`
  tgt_balance=`$cli_target getbalance`


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

  printbalance
  echo "Sending $amount from $source to $target at $(date)"

  echo "Raw tx that we will work with"
  txraw=`$cli_source createrawtransaction "[]" "{\"$address\":$amount}"`
  echo "$txraw txraw"
  echo "Convert to an export tx"
  exportData=`$cli_source migrate_converttoexport $txraw $target $amount`
  echo "$exportData exportData"
  exportRaw=`echo $exportData | jq -r .exportTx`
  echo "$exportRaw exportRaw"
  echo "Fund it"
  exportFundedData=`$cli_source fundrawtransaction $exportRaw`
  echo "$exportFundedData exportFundedData"
  exportFundedTx=`echo $exportFundedData | jq -r .hex`
  echo "$exportFundedTx exportFundedTx"
  payouts=`echo $exportData | jq -r .payouts`
  echo "$payouts payouts"

  echo "4. Sign rawtx and export"
  signedhex=`$cli_source signrawtransaction $exportFundedTx | jq -r .hex`
  echo "$signedhex signedhex"
  sentTX=`$cli_source sendrawtransaction $signedhex`
  echo "$sentTX sentTX"

  txidsize=${#sentTX}
  if [[ $txidsize != "64" ]]; then
    echo "Export TX not sucessfully created"
    echo "$sentTX"
    echo "$signedhex"
    exit
  fi

  echo "5. Wait for a confirmation on source chain."
  waitforconfirm "$sentTX" "$cli_source"
  echo "[$source] : Confirmed export $sentTX"

  echo " 6. Use migrate_createimporttransaction to create the import TX"
  created=0
  while [[ ${created} -eq 0 ]]; do
    sleep 60
    importTX=`$cli_source migrate_createimporttransaction $signedhex $payouts`
    echo "$importTX importTX"
    if [[ ${importTX} != "" ]]; then
      created=1
    fi
  done
  echo "importTX"
  echo "Create import transaction sucessful!"

  # 8. Use migrate_completeimporttransaction on KMD to complete the import tx
  created=0
  while [[ $created -eq 0 ]]; do
    sleep 60
    completeTX=`komodo-cli migrate_completeimporttransaction $importTX`
    echo "$completeTX completeTX"
    if [[ $completeTX != "" ]]; then
      created=1
    fi
  done
  echo "Sign import transaction on KMD complete!"

  # 9. Broadcast tx to target chain
  sent=0
  tries=0
  while [[ $sent -eq 0 ]]; do
    sleep 60
    sent_iTX=`$cli_target sendrawtransaction $completeTX 2> /dev/null`
    if [[ ${#sent_iTX} = "64" ]]; then
      sent=1
    elif [[ $sent_iTX != "" ]]; then
      echo "------------------------------------------------------------"
      echo "Invalid txid returned from send import transacton"
      echo "$sent_iTX"
      echo "$completeTX"
      echo "-------------------------------------------------------------"
      exit
    else
      tries=$(( $tries +1 ))
      if [[ $tries -ge 60 ]]; then
        echo "------------------------------------------------------------"
        echo "Failed Import TX on $target at $(date)"
        echo "Exiting after 90 tries: $completeTX"
        echo "From Chain: $source"
        echo "Export TX: $sentTX"
        echo "$signedhex $payouts"
        echo "------------------------------------------------------------"
        echo "$(date)   $signedhex $payouts" >> FAILED
        exit
      fi
    fi
  done

  waitforconfirm "$sent_iTX" "$cli_target"
  echo "[$target] : Confirmed import $sent_iTX at $(date)"
  printbalance




      colorIndex=$(echo $colorIndex+1|bc)
      if [ $colorIndex -ge ${#colors[@]} ]; then
        colorIndex=0;
      fi
  done

done
