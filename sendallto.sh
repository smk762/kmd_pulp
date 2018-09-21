# Sends all funds in wallet for each Staked asset chain to a common native address. Used to consolidate funds (does not migrate across chains!)
if [[ $(komodo-cli validateaddress ${1} | jq -r '.isvalid') != false ]]; then
	ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
	for chain in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
	  balance=$(komodo-cli -ac_name=${chain} getbalance)
	  if [[ $balance > 0 ]]; then
	  	echo "[ ${chain} ] Sending ${balance} ${chain} to ${1}"
	  	komodo-cli -ac_name=${chain} sendtoaddress ${1}  ${balance} "" "" true
	  else
	  	echo "No funds in ${chain} wallet to send!"
	  fi
	done
else 
	echo "INVALID ADDRESS, TRY AGAIN."
	echo "Usage: sendall <R-address>"
fi
