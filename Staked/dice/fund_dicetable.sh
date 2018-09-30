#!/bin/bash

#Usage: ./fund_dicetable.sh [ac_name] [tablename] [tabletxid] [amount]

col_red="\e[31m"
col_green="\e[32m"
col_yellow="\e[33m"
col_blue="\e[34m"
col_magenta="\e[35m"
col_cyan="\e[36m"
col_default="\e[39m"
col_dkgrey="\e[90m"
colors=($col_red $col_green $col_yellow $col_blue $col_magenta $col_cyan)

ac_name=$1
tablename=$2
tabletxid=$3
amount=$4



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


prompt_confirm "Fund table with extra utxos?" || exit


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

ac_name="STAKEDW1"
table_name="Larry"
table_txid="49869c0b3907c82ccbbaa6f90ebedb1f2323d2c16f925cb8c14c1ee580c7f43d"

#split into a loop for more utxos
for ((c=1; c<=$utxo_count; c++)); do
  echo "creating raw table funding tx"
  dice_fund_raw=$(komodo-cli -ac_name=$ac_name diceaddfunds $table_name $table_txid $utxo_val)
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