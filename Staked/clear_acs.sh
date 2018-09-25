#!/bin/bash

ac_json=$(curl https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json 2>/dev/null)
for row in $(echo "${ac_json}" | jq  -r '.[].ac_name'); do
	chain=$(echo $row)
	echo "deleting ${chain} blocks and chainstate"
	rm -rf /home/$USER/.komodo/${chain}/blocks
        rm -rf /home/$USER/.komodo/${chain}/chainstate
done
echo "done"
