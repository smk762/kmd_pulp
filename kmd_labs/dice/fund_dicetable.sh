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
OOO=("Cauthon" "photon" "autobot" "Doc")



ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
num_chains=$(echo "${ac_json}" | jq  -r '. | length');
for chain_params in $(echo "${ac_json}" | jq  -c -r '.[]'); do
    ac_private=$(echo $chain_params | jq -r '.ac_private')
    if [[ $ac_private != 1 ]]; then
      ac_name=$(echo $chain_params | jq -r '.ac_name')
    # Checking if asset chain is configured
    if [ ! -d ~/.komodo/${ac_name}  ]; then
      echo -e "\e[91m [ $ac_name ] CONF FILE DOES NOT EXIST!"
                echo -e "Sync the chains first! \e[39m"
      exit 1
    fi
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

    if [[ $(cat ~/wallets/.STAKEDB1_wallet | grep $myaddress) == "" ]]; then
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
    echo -e "===== ${col_magenta} You have $balance $ac_name to fund with using pubkey $pubkey ====="
  fi
done

# use pub key from dice address in your wallet
# pubkey=$(komodo-cli -ac_name=${ac_name} validateaddress $myaddress | jq -r '.pubkey')


  header=" %-3s %-12s %-14s  %7s  %7s  %8s  %7s  %5s  %-64s\n"
  format=" %-3s %-12s %-14s  %7d  %7d  %8d  %7d  %5.0f  %-64s\n"
  i=1
  ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
  num_chains=$(echo "${ac_json}" | jq  -r '. | length');
  echo -e "${col_yellow}----------------------------------------------------------------------------------------------------------------------------------------------${col_default}"
  echo -e "${col_yellow}----------------------------------------------------- ${col_cyan} S E L E C T   A   T A B L E ${col_yellow} ----------------------------------------------------------"
  echo -e "${col_yellow}----------------------------------------------------------------------------------------------------------------------------------------------${col_default}"
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
        table_chains+=("$ac_name")
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
        if echo ${OOO[@]} | grep -q -w "$name"; then 
          name="Out of Order!"
          #echo -e "${col_red}"
          #printf "$format" "$i" "$ac_name" "$name" "$minbet" "$maxbet" "$maxodds" "$timeout" "$funding" "$table"  
          #echo -e ${colors[$j]}         
        else 
          printf "$format" "$i" "$ac_name" "$name" "$minbet" "$maxbet" "$maxodds" "$timeout" "$funding" "$table"
        fi
        ((i=$i+1))
      done
    fi  
  done
  echo -e "${col_yellow}----------------------------------------------------------------------------------------------------------------------------------------------${col_default}"

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
  tableIndex=$(echo $tableIndex-1|bc)
  ac_name=${table_chains[${tableIndex}]}
  funding_txid="${dice_tables[${tableIndex}]}"
  tableInfo=$(komodo-cli -ac_name=$ac_name diceinfo $funding_txid)
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
  table_num=$(echo $tableIndex+1|bc)
  printf "$format" "$table_num" "$ac_name" "$name" "$minbet" "$maxbet" "$maxodds" "$timeout" "$funding" "$funding_txid"

  balance=$(printf '%.0f' $(komodo-cli -ac_name=$ac_name getbalance))
  echo -e "===== ${col_magenta} You have $balance $ac_name to fund using pubkey $pubkey ====="


  while [[ true ]]; do
    echo -e "${col_blue}"
    read -p "How many utxos?: " utxo_count
    echo -e "${col_default}"
    if [ $utxo_count -ge 0 2>/dev/null ]; then  
      utxo_count=$utxo_count
    break
    else
      echo -e "${col_ltred}Invalid input, try again.${col_default}"
    fi
  done

  while [[ true ]]; do
    echo -e "${col_blue}"
    read -p "Value per utxo?: " utxo_val
    echo -e "${col_default}"
    if [ $utxo_val -ge 0 2>/dev/null ]; then  
      utxo_val=$utxo_val
    break
    else
      echo -e "${col_ltred}Invalid input, try again.${col_default}"
    fi
  done

#split into a loop for more utxos
for ((c=1; c<=$utxo_count; c++)); do
  echo "creating raw table funding tx"
  echo $name $funding_txid $utxo_val
  dice_fund_raw=$(komodo-cli -ac_name=$ac_name diceaddfunds $name $funding_txid $utxo_val)
  echo -e "${col_dkgrey}$dice_fund_raw ${col_default}"

  result=$(echo $dice_fund_raw | jq -r '.result')
  while [ "$result" == "error" ]; do
    dice_fund_raw=$(komodo-cli -ac_name=$ac_name diceaddfunds $name $funding_txid $utxo_val)
    hex=$(echo $dice_fund_raw | jq -r '.hex')
    error=$(echo $dice_fund_raw | jq -r '.error')
    result=$(echo $dice_fund_raw | jq -r '.result')
    if [[ $result == "error" ]]; then
      echo " waiting for next roll"
      if [[ $error == "only fund creator can add more funds (entropy)" ]]; then
        echo "Only table owner can add funds! Exiting..."              
        exit 1
      fi
    fi
  done
  fund_hex=$(echo $dice_fund_raw | jq -r '.hex')
  echo "HEX: $fund_hex"
  echo "broadcasting raw table funding tx"
  send_raw_hex=$(komodo-cli -ac_name=$ac_name sendrawtransaction $fund_hex)
  rawmempool=$(komodo-cli -ac_name=$ac_name getrawmempool)
  confirmfunds=$(echo $rawmempool | jq '.[]' | grep $send_raw_hex) 2>/dev/null

  while [ -z "$confirmfunds" ]; do
    echo -e "${col_dkgrey}waiting for confirmation${col_default}"
    sleep 10
    rawmempool=$(komodo-cli -ac_name=$ac_name getrawmempool)
    confirmfunds=$(echo $rawmempool | jq '.[]' | grep $send_raw_hex) 2>/dev/null
  done
  echo -e "${col_green}Funds confirmed in mempool with with txid: $confirmfunds${col_default}"
done