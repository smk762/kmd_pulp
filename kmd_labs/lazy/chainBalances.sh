#!/bin/bash
# Get latest chain parameters
ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
num_chains=$(echo "${ac_json}" | jq  -r '. | length');
# Get total balance accross all chains
min=99999999999
max=0
echo "============================================================"
for chain in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
  balance="$(komodo-cli -ac_name=$chain getbalance)"
  if [ $balance -lt $min ]; then
    min=$(printf '%.0f' $(echo $balance))
  fi
  if [  $balance -gt $max ]; then
  max=$(printf '%.0f' $(echo $balance))
  fi
    total_balance=$(echo $balance+$total_balance|bc)
  delta=$(printf '%.0f' $(echo $balance-$average|bc))
  if [ $delta -gt 0 ]; then
    echo -e "$chain balance = $(echo $balance)\e[94m (Adding to sources) - $delta coins to spare. ${col_default}"
    sources+=($chain)
  else
    echo -e "$chain balance = $(echo $balance)\e[93m (Adding to targets) - needs ${delta#-} coins. ${col_default}"
    targets+=($chain)
  fi
done
range=$(echo $max-$min|bc)
average=$(echo $total_balance/$num_chains|bc)
echo -e "\e[92m[TOTAL BALANCE :  ${total_balance}]${col_default}"
echo -e "\e[92m[Average balance = ${average}]${col_default}"
echo -e "\e[92m[Min balance = ${min}]${col_default}"
echo -e "\e[92m[Max balance = ${max}]${col_default}"
echo -e "\e[92m[Range = ${range}]${col_default}"
echo "============================================================"
echo "Sources: $sources[@]"
echo "Targets: $targets[@]"
echo "============================================================"
