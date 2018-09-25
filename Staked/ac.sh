#!/bin/bash

ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
for row in $(echo "${ac_json}" | jq -c -r '.[]'); do
	_jq() {
     		echo ${row} | jq -r ${1}
    	}
	chain=$(_jq '.ac_name')


            info=$(komodo-cli -ac_name=$name getinfo)
            txinfo=$(komodo-cli -ac_name=$name listtransactions "" $txscanamount)

            printf "$format" "$name" \
                    "$(echo $txinfo | grep -- $kmdntrzaddr | wc -l)" \
                    "$(komodo-cli -ac_name=$name listunspent | grep $utxoamt | wc -l)" \
                    "$(echo $info | awk ' /\"blocks\"/ {printf $2}' | sed 's/,//')" \
"$(echo $info | awk ' /\"balance\"/ {printf $2}' | sed 's/,//')" 
done
