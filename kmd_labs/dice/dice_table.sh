#!/bin/bash

col_red="\e[31m"
col_green="\e[32m"
col_yellow="\e[33m"
col_blue="\e[34m"
col_magenta="\e[35m"
col_cyan="\e[36m"
col_default="\e[39m"
col_dkgrey="\e[90m"
colors=($col_red $col_green $col_yellow $col_blue $col_magenta $col_cyan)


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


# Set chain dice is being played on
if [[ -z $1 ]]; then
  ac_name="STAKEDB1"
else
  ac_name=$1
fi

# Checking if asset chain selected is configured
if [ ! -d ~/.komodo/${ac_name}  ]; then
  echo -e "\e[91m [ $ac_name ] CONF FILE DOES NOT EXIST!"
            echo -e "Sync the chains first! \e[39m"
  exit 1
fi


echo -e "${col_blue}***********************************************************************"
echo -e "**** KOMODO's STAKED CHAINS - DICE CRYPTO-CONDITIONS TABLE EXAMPLE ****"
echo -e "***********************************************************************${col_default}"
echo ""

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
balance=$(printf '%.0f' $(komodo-cli -ac_name=$ac_name getbalance))
echo -e "===== ${col_magenta} You have $balance $ac_name to bet using pubkey $pubkey ====="


  while [[ true ]]; do
    echo -e "${col_blue}"
    read -p "Set table name: " table_name
    echo -e "${col_default}"
    break
  done


  while [[ true ]]; do
    echo -e "${col_blue}"
    read -p "Set Funds (100 minimum - Go low & send more utxos later.): " funds
    echo -e "${col_default}"
    if [ $funds -ge 0 2>/dev/null ]; then  
      if [[ $funds -gt $balance ]]; then
        echo -e "${col_ltred}Insufficient funds, try again${col_default}"
      elif [[ $funds -lt 100 ]]; then
        echo -e "${col_ltred}Table minimum is 100 $ac_name, try again${col_default}"
      else
        break
      fi
    else
      echo -e "${col_ltred}Invalid input, try again.${col_default}"
    fi
  done


  while [[ true ]]; do
    echo -e "${col_blue}"
    read -p "Set minbet: " minbet
    echo -e "${col_default}"
    if [ $minbet -ge 0 2>/dev/null ]; then  
      minbet=$minbet
    break
    else
      echo -e "${col_ltred}Invalid input, try again.${col_default}"
    fi
  done

  while [[ true ]]; do
    echo -e "${col_blue}"
    read -p "Set maxbet: " maxbet
    echo -e "${col_default}"
    if [ $maxbet -ge 0 2>/dev/null ]; then  
      maxbet=$maxbet
    break
    else
      echo -e "${col_ltred}Invalid input, try again.${col_default}"
    fi
  done

  while [[ true ]]; do
    echo -e "${col_blue}"
    read -p "Set maxodds: " maxodds
    echo -e "${col_default}"
    if [ $maxodds -ge 0 2>/dev/null ]; then  
      maxodds=$maxodds
    break
    else
      echo -e "${col_ltred}Invalid input, try again.${col_default}"
    fi
  done


  while [[ true ]]; do
    echo -e "${col_blue}"
    read -p "Set timeout: " timeout
    echo -e "${col_default}"
    if [ $timeout -ge 0 2>/dev/null ]; then  
      timeout=$timeout
    break
    else
      echo -e "${col_ltred}Invalid input, try again.${col_default}"
    fi
  done
echo "-ac_name=$ac_name dicefund $table_name $funds $minbet $maxbet $maxodds $timeout)"
table=$(komodo-cli -ac_name=$ac_name dicefund $table_name $funds $minbet $maxbet $maxodds $timeout)
table_hex=$(echo $table | jq -r '.hex')
echo $table_hex

table_txid=$(komodo-cli -ac_name=$ac_name sendrawtransaction $table_hex)
echo $table_txid

rawmempool=$(komodo-cli -ac_name=$ac_name getrawmempool)
confirmbet=$(echo $rawmempool | jq '.[]' | grep $table_txid)

while [ -z "$confirmbet" ]; do
	echo -e "${col_dkgrey}waiting for confirmation${col_default}"
	sleep 10

	rawmempool=$(komodo-cli -ac_name=$ac_name getrawmempool)"."
  confirmbet=$(echo $rawmempool | jq '.[]' | grep $table_txid)
done
echo -e "${col_green}Table confirmed in mempool with with txid: $confirmbet${col_default}"
sleep 5
diceTables=$(komodo-cli -ac_name=$ac_name dicelist)
diceList=$(echo $diceTables | jq -r '.[]')
numTables=${#diceList[@]}
sleep 5
echo -e "${col_green} ---- DICE TABLES ---- ${col_yellow}"
i=1
for table in $diceList; do
	echo -e "${col_cyan}$i - $table${col_default}"
	((i=$i+1))
done


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