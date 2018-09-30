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

ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
num_chains=$(echo "${ac_json}" | jq  -r '. | length');
for chain_params in $(echo "${ac_json}" | jq  -c -r '.[]'); do
    ac_name=$(echo $chain_params | jq -r '.ac_name')
    ac_private=$(echo $chain_params | jq -r '.ac_private')
    if [[ $ac_private != 1 ]]; then
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
      balance=$(komodo-cli -ac_name=$ac_name getbalance)
      echo -e "===== ${col_magenta} You have $balance $ac_name to bet using pubkey $pubkey ====="


      # set player name
      table_name="Homer"
      # use pub key from address in your wallet
      funds=100
      minbet=5
      maxbet=5
      maxodds=5
      timeout=2


      #dicefund name funds minbet maxbet maxodds timeoutblocks

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
      echo -e "${col_green} ---- DICE TABLES ---- ${col_yellow}"
      i=1
      for table in $diceList; do
        echo -e "${col_cyan}$i - $table${col_default}"
        ((i=$i+1))
      done

      prompt_confirm "Fund table with utxos? (will send 20 diceaddfunds)" || exit 0

      #split into a loop for more utxos
      for ((c=1; c<=20; c++)); do
        echo "creating raw table funding tx"
        dice_fund_raw=$(komodo-cli -ac_name=$ac_name diceaddfunds $table_name $table_txid 1)
        fund_hex=$(echo $dice_fund_raw | jq -r '.hex')


        echo "broadcating raw table funding tx"
        dice_fund_raw=$(komodo-cli -ac_name=$ac_name sendrawtransaction $fund_hex)

        rawmempool=$(komodo-cli -ac_name=$ac_name getrawmempool)
        confirmfunds=$(echo $rawmempool | jq '.[]' | grep $table_txid)

        while [ -z "$confirmfunds" ]; do
          echo -e "${col_dkgrey}waiting for confirmation${col_default}"
          sleep 10

        rawmempool=$(komodo-cli -ac_name=$ac_name getrawmempool)
        confirmfunds=$(echo $rawmempool | jq '.[]' | grep $table_txid)
        done
        echo -e "${col_green}Funds confirmed in mempool with with txid: $confirmfunds${col_default}"
      done
    fi
done
