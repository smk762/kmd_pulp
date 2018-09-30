#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

# Optionally just split UTXOs for a single coin
# e.g "KMD"
specific_coin=$1


kmd_target_utxo_count=100
kmd_split_threshold=50

other_target_utxo_count=25
other_split_threshold=15

date=$(date +%Y-%m-%d:%H:%M:%S)

calc() {
  awk "BEGIN { print "$*" }"
}

if [[ -z "${specific_coin}" ]]; then
  echo "----------------------------------------"
  echo "Splitting UTXOs - ${date}"
  echo "KMD target UTXO count: ${kmd_target_utxo_count}"
  echo "KMD split threshold: ${kmd_split_threshold}"
  echo "Other target UTXO count: ${other_target_utxo_count}"
  echo "Other split threshold: ${other_split_threshold}"
  echo "----------------------------------------"
fi

ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
num_chains=$(echo "${ac_json}" | jq  -r '. | length');
for chain_params in $(echo "${ac_json}" | jq  -c -r '.[]'); do
    ac_name=$(echo $chain_params | jq -r '.ac_name')
  if [[ -z "${specific_coin}" ]] || [[ "${specific_coin}" = "${ac_name}" ]]; then
    ac_flag="-ac_name=${ac_name}"

    if [[ "${ac_name}" = "KMD" ]]; then
      ac_flag=""
      target_utxo_count=$kmd_target_utxo_count
      split_threshold=$kmd_split_threshold
    else
      target_utxo_count=$other_target_utxo_count
      split_threshold=$other_split_threshold
    fi

    satoshis=10000
    amount=$(calc $satoshis/100000000)
    listunspent=$(komodo-cli $ac_flag listunspent)
    if [[ "${listunspent}" = "" ]]; then
      echo "[$coin] Listuspent call failed aborting!"
    else
      utxo_count=$(echo ${listunspent} | jq -r '.[].amount' | grep ${amount} | wc -l)
      echo "[${ac_name}] Current UTXO count is ${utxo_count}"

      utxo_required=$(calc ${target_utxo_count}-${utxo_count})

      if [[ ${utxo_required} -gt ${split_threshold} ]]; then
        echo "[${ac_name}] Splitting ${utxo_required} extra UTXOs"       
        json=$(echo $(curl http://127.0.0.1:7776 --silent --data "{\"coin\":\"${ac_name}\",\"agent\":\"iguana\",\"method\":\"splitfunds\",\"satoshis\":10000,\"sendflag\":1,\"duplicates\":${utxo_required}}"))
        echo $json
        txid=$(echo ${json} | jq -r '.txid')
        if [[ ${txid} != "null" ]]; then
          echo "[${ac_name}] Split TXID: ${txid}"
        else
          echo "[${ac_name}] Error: $(echo ${json} | jq -r '.error')"
        fi
      fi
    fi
  fi
done
