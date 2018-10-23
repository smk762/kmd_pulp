#!/bin/bash

cli="komodo-cli -ac_name=STAKEDW1"
#pubkey=0340ed83df564a37c637c39c83fa8c5c8e864072c4567f1b85d20f10982aadeca3
pubkey=02fd42d293ede25a345b9da4337e6ecafd9bdd99009b50e9e39fb462a71d7dfd20
numpayments=10
paydenom=1
amount=10

echo "1"
#echo $pubkey
#echo $numpayments
#echo $paydenom
channelsopen=$($cli channelsopen $pubkey $numpayments $paydenom)
echo $channelsopen
echo "2."
openhex=$(echo $channelsopen | jq -r '.hex')
echo $openhex
echo "3."
sendopenraw=$($cli sendrawtransaction "$openhex")
echo $sendopenraw
#echo "4."
#open_tx_id=$(echo "$sendopenraw" | jq -r '.hex')
#echo $open_tx_id
echo "5."
channelspayment=$($cli channelspayment "$sendopenraw" "$amount")
#channelspayment=$($cli channelspayment $openhex $amount)
echo "5: $channelspayment"
echo "6."
sendpaymentraw=$(echo $channelspayment | jq -r '.hex')
echo $sendpaymentraw
echo "7."
sendpayment=$($cli sendrawtransaction "$sendpaymentraw")
echo "8."
echo "That's it! You have probably lost your funds.  This is a totally noob script afterall..."
