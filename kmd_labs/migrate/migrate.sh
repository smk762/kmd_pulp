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

initTime=$SECONDS

if [[ ! -d $HOME/.komodo/migration_logs ]]; then
  mkdir $HOME/.komodo/migration_logs
fi

result_logfile="$HOME/.komodo/migration_logs/migrate_results.log"
if [[ ! -z $result_logfile ]]; then
  touch $result_logfile
fi

# This script makes the neccesary transactions to migrate
# coin between 2 assetchains on the same -ac_cc id
waitforconfirm () {
  logfile="$HOME/.komodo/migration_logs/${1}.log"
  #echo "logfile: $logfile"
  confirmations=0
  while [[ ${confirmations} -lt 1 ]]; do
    runTime=$(echo $SECONDS-$initTime|bc)
    #echo "$1 $2"
    echo "Waiting for confirmations ($runTime sec)"
    confirmations=$($2 gettransaction $1 | jq -r '.confirmations')
    # Keep re-broadcasting
    $2 getrawtransaction $1 > $logfile
    $2 sendrawtransaction $($2 getrawtransaction $1) > /dev/null 2>&1
    sleep 15
  done
}

printbalance () {
  src_balance=`$cli_source getbalance`
  tgt_balance=`$cli_target getbalance`
  echo -e "${col_cyan}[$source] : $src_balance"
  echo -e "[$target] : ${tgt_balance}${col_default}"
}

ac_json=$(cat "$HOME/StakedNotary/assetchains.json")
ac_list=();
src_balance=();
tgt_balance=();
for chain_params in $(echo "${ac_json}" | jq  -c -r '.[]'); do
  ac_name=$(echo $chain_params | jq -r '.ac_name')
  ccid=$(echo $chain_params | jq -r '.ac_cc')
  ac_list+=("$ac_name (ccid: ${ccid})")
  cli_source="komodo-cli -ac_name=$ac_name"
  src_balance=$($cli_source getbalance)
  echo -e "${col_green}$ac_name (balance: $src_balance)"
done

echo -e -n "$col_blue"
PS3="Select source asset chain: "
while [[ ${#source} < 3 ]]; do
  select ac in "${ac_list[@]}"
  do
      echo -e -n "$col_yellow"
      selected=($ac)
      source=${selected[0]}
      ccid_src=$(echo "${selected[2]}" | sed 's=(==' | sed 's=)==')
      cli_source="komodo-cli -ac_name=$source"
      src_balance=$($cli_source getbalance)
      break
  done
  echo -e -n "$col_blue"
  PS3="Select source asset chain: "
  echo -e -n "$col_yellow"
done
echo "$source selected (balance: $src_balance)"

echo -e -n "$col_blue"
PS3="Select target asset chain: "
while [[ ${#target} < 3 ]]; do
  select ac in "${ac_list[@]}"
  do
  echo -e -n "$col_yellow"
      selected=($ac)
      target=${selected[0]}
      ccid_tgt=$(echo "${selected[2]}" | sed 's=(==' | sed 's=)==')
      cli_target="komodo-cli -ac_name=$target"
      tgt_balance=$($cli_target getbalance)
      break
  done
  echo -e -n "$col_blue"
  PS3="Select source asset chain: "
  echo -e -n "$col_yellow"
done
echo "$target selected (balance: $tgt_balance)"

if [[ "$ccid_tgt" != "$ccid_src"  ]]; then
    echo "Cant migrate to coins on different CC IDs! Aborting..."
   exit 1;
fi

int=${float%.*}
amount=$(echo ${src_balance%.*}+1|bc)
while [[ ${amount%.*} -gt ${src_balance%.*} ]]; do 
  echo -e -n "${col_blue}Enter sum to send: ${col_default}"
  read amount
done

echo -e -n "$col_blue"
PS3="Select target address: "
echo -e -n "$col_yellow"
addresses=($(komodo-cli -ac_name=$target listaddressgroupings | jq -r '.[][][0]'))
if [[ ${#addresses[@]} -gt 0 ]]; then
  while [[ ${#trg_addr} -ne 34 ]]; do
    select address in ${addresses[@]}
    do
      trg_addr=$address
      break
    done
  done
  else
    while [[ ${#trg_addr} -ne 34 ]]; do 
      echo -e -n "${col_blue}Enter target address: ${col_default}"
      read trg_addr
    done
fi
init_txt="Sending $amount from $source to $trg_addr on $target at $(date)"
echo $init_txt
echo $init_txt >> $result_logfile

printbalance

# Raw tx that we will work with
txraw=$($cli_source createrawtransaction "[]" "{\"$trg_addr\":$amount}")
echo "-------------createrawtransaction----------------------"
echo -e "${col_cyan}"
echo 'createrawtransaction "[]" "{\"'$trg_addr'\":'$amount'}"'
echo -e "${col_green}INPUT target:${col_default} $target"
echo -e "${col_green}INPUT target address:${col_default} $trg_addr"
echo -e "${col_green}INPUT amount:${col_default} $amount"
echo -e "${col_yellow}RETURNS txraw:${col_default} $txraw"
echo "-----------------------------------------------------"
# Convert to an export tx
exportData=`$cli_source migrate_converttoexport $txraw $target`
echo "exportData: $exportData" >> $result_logfile
exportTx=`echo $exportData | jq -r .exportTx`
payouts=`echo $exportData | jq -r .payouts`
echo "-------------migrate_converttoexport-----------------"
echo -e "${col_cyan}"
echo "migrate_converttoexport $txraw $target"
echo -e "${col_green}INPUT txraw:${col_default} $txraw"
echo -e "${col_green}INPUT target:${col_default} $target"
echo -e "${col_yellow}RETURNS exportTx:${col_default} $exportTx"
echo -e "${col_yellow}RETURNS payouts:${col_default} $payouts"
echo "-----------------------------------------------------"

# Fund it
exportFundedData=`$cli_source fundrawtransaction $exportTx`
exportFundedTx=`echo $exportFundedData | jq -r .hex`
echo "exportFundedData: $exportFundedData" >> $result_logfile
echo "exportFundedTx: $exportFundedTx" >> $result_logfile
echo "-------------fundrawtransaction----------------------"
echo -e "${col_cyan}"
echo "fundrawtransaction $exportTx"
echo -e "${col_green}INPUT exportTx:${col_default} $exportTx"
echo -e "${col_yellow}RETURNS exportFundedData:${col_default} $exportFundedData"
echo -e "${col_yellow}RETURNS exportFundedTx:${col_default} $exportFundedTx"
echo "-----------------------------------------------------"

# 4. Sign rawtx and export
signedtx=`$cli_source signrawtransaction $exportFundedTx`
signedhex=`echo $signedtx | jq -r .hex`
echo "signedhex: $signedhex" >> $result_logfile
echo "-------------signrawtransaction----------------------"
echo -e "${col_cyan}"
echo "signrawtransaction $exportFundedTx"
echo -e "${col_green}INPUT exportFundedTx:${col_default} $exportFundedTx"
echo -e "${col_yellow}RETURNS signedtx:${col_default} $signedtx"
echo -e "${col_yellow}RETURNS signedhex:${col_default} $signedhex"
echo "-----------------------------------------------------"

sentTX=`$cli_source sendrawtransaction $signedhex`
echo "sentTX: $sentTX" >> $result_logfile
echo "-------------sendrawtransaction----------------------"
echo -e "${col_cyan}"
echo "sendrawtransaction $signedhex"
echo -e "${col_green}INPUT signedhex:${col_default} $signedhex"
echo -e "${col_yellow}RETURNS sentTX:${col_default} $sentTX"
echo "-----------------------------------------------------"


# Check if export transaction was created sucessfully
txidsize=${#sentTX}
if [[ $txidsize != "64" ]]; then
  echo -e "${col_red}Export TX not sucessfully created${col_default}"
  echo "$sentTX"
  echo "$signedhex"
  exit
fi

# 5. Wait for a confirmation on source chain.
waitforconfirm "$sentTX" "$cli_source"
echo -e "[$source] : ${col_green}Confirmed export $sentTX${col_default}"
echo -e "[$source] : ${col_green}Confirmed export $sentTX${col_default}" >> $result_logfile
#echo "$cli_source migrate_createimporttransaction $signedhex $payouts"

  #  {
   #   "txid": "2ef15e2b4b6739a598d849489f963ae347d8c23b76a1bee360b7da24c96d884d",
    #  "amount": 2.00000000,
     # "address": "RAwx45zENMPa2p4AGnGmbrFEw6wtGoUXi6",
      #"export": {
#        "txid": "114f160197bb757cbc7bb1d3e54a24670dcda1f9993528d5a735b992745964f8",
 #       "amount": 2.00000000,
  #      "source": "CFEKY"
   #   }
  export_blockheight=$($cli_source getinfo | jq '.blocks')
  export_json='{"export_txid":"'${sentTX}'","amount":'${amount}',"to_address":"'${trg_addr}'","from_chain":"'${source}'","to_chain":"'${target}'","export_blockheight":"'${export_blockheight}'"}'

# 6. Use migrate_createimporttransaction to create the import TX
created=0
while [[ ${created} -eq 0 ]]; do
  echo "creating import tx... ($runTime sec)"
  sleep 60
  importTX=$($cli_source migrate_createimporttransaction $signedhex $payouts 2> /dev/null)
  echo "$cli_source migrate_createimporttransaction $signedhex $payouts 2> /dev/null"
  if [[ "${importTX}" != "" ]]; then
    created=1
  fi
  runTime=$(echo $SECONDS-$initTime|bc)
done
echo "-------------migrate_createimporttransaction---------------"
echo -e "${col_cyan}"
echo "migrate_createimporttransaction $signedhex $payouts"
echo -e "${col_green}INPUTsignedhex:${col_default} $signedhex"
echo -e "${col_green}INPUT payouts:${col_default} $payouts"
echo -e "${col_yellow}RETURNS importTX:${col_default} $importTX"
echo "-----------------------------------------------------------"
echo -e "${col_green}Create import transaction successful! (${runTime} sec)${col_default}"
echo "importTX: $importTX" >> $result_logfile
echo -e "${col_green}Create import transaction successful! (${runTime} sec)${col_default}" >> $result_logfile

echo "komodo-cli migrate_completeimporttransaction $importTX"

# 8. Use migrate_completeimporttransaction on KMD to complete the import tx
created=0
while [[ $created -eq 0 ]]; do
  echo "Signing import tx on KMD... ($runTime sec)"
  sleep 60
  completeTX=`komodo-cli migrate_completeimporttransaction $importTX 2> /dev/null`
  echo $completeTX
  if [[ $completeTX != "" ]]; then
    created=1
  fi
  runTime=$(echo $SECONDS-$initTime|bc)
done
echo "-------------migrate_completeimporttransaction---------------"
echo -e "${col_cyan}"
echo "migrate_completeimporttransaction $importTX"
echo -e "${col_green}INPUT importTX:${col_default} $importTX"
echo -e "${col_yellow}RETURNS completeTX:${col_default} $completeTX"
echo "-----------------------------------------------------------"
echo "completeTX: $completeTX" >> $result_logfile
echo -e "${col_green}Sign import transaction on KMD complete! ($runTime sec)${col_default}" >> $result_logfile
echo -e "${col_green}Sign import transaction on KMD complete! ($runTime sec)${col_default}"

echo "$cli_target sendrawtransaction $completeTX"

# 9. Broadcast tx to target chain
sent=0
tries=0
while [[ $sent -eq 0 ]]; do
  runTime=$(echo $SECONDS-$initTime|bc)
  echo "broadcasting import tx... ($runTime sec)"
  sleep 60
  sent_iTX=`$cli_target sendrawtransaction $completeTX 2> /dev/null`
  blockheight=$($cli_target getinfo | jq '.blocks')
  if [[ ${#sent_iTX} = "64" ]]; then
    sent=1
  elif [[ $sent_iTX != "" ]]; then
    echo -e "${col_red}"
    echo "------------------------------------------------------------"
    echo "Invalid txid returned from send import transacton"
    echo "Invalid txid returned from send import transacton" >> $result_logfile
    echo "$sent_iTX"
    echo "$completeTX"
    echo "-------------------------------------------------------------"
    echo -e "${col_default}"
    exit
  else
    tries=$(( $tries +1 ))
    if [[ $tries -ge 90 ]]; then
      echo -e "${col_red}"
      echo "------------------------------------------------------------"
      echo "Failed Import TX on $target at $(date)"
      echo "Exiting after 90 tries: $completeTX"
      echo "Exiting after 90 tries: $completeTX" >> $result_logfile
      echo "From Chain: $source"
      echo "Export TX: $sentTX"
      echo "$signedhex $payouts"
      echo "------------------------------------------------------------"
      echo -e "${col_default}"
      echo "$(date)   $signedhex $payouts" >> FAILED
      exit
    fi
  fi
done
echo "-------------sendrawtransaction----------------------"
echo -e "${col_cyan}"
echo "sendrawtransaction $completeTX"
echo -e "${col_green}INPUT completeTX:${col_default} $completeTX"
echo -e "${col_yellow}RETURNS sent_iTX:${col_default} $sent_iTX"
echo "-----------------------------------------------------"

waitforconfirm "$sent_iTX" "$cli_target"
runTime=$(echo $SECONDS-$initTime|bc)
#blockheight=$(echo "$($cli_target getinfo | jq '.blocks')-1" | bc)

echo "sent_iTX: $sent_iTX" >> $result_logfile
echo -e "${col_green}[$target] : Confirmed import $sent_iTX at $(date) ($runTime sec) on block ${blockheight}${col_default}"
echo -e "${col_green}[$target] : Confirmed import $sent_iTX at $(date) ($runTime sec) on block ${blockheight}${col_default}" >> $result_logfile
echo "********************************************************************************************************************************" >> $result_logfile
printbalance
echo $export_json
$cli_target getimports $blockheight

#komodo-cli -ac_name=CFEKX getimports $(echo $(komodo-cli -ac_name=CFEKX getinfo | jq '.blocks')-10 | bc)
#that wont give you any info about exports, until the import has been completed ...
#Becasuse that data is very hard to get ... which is why the migrate script its supposed to publish that to an oracle.