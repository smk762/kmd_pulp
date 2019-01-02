#!/bin/bash
#orclid must be an existing S oracle with registered publisher
#sub must be a registered publisher
orclid=42b0a3a7cd32160cbe077145024f1fd585663e5e355dc70b92b38ff67cb776f3
sub=02f0f676306292a1aea497a494c9d5603e184c3e6f456e1f140b67014d980be116
pubs=$(komodo-cli -ac_name=CFEK oraclesinfo $orclid | jq -r '.registered | .[] | .publisher')
pubsarray=(${pubs///n/ })
batons=$(komodo-cli -ac_name=CFEK oraclesinfo $orclid | jq -r '.registered | .[] | .batontxid')
batonarray=(${batons///n/ })
len=$(komodo-cli -ac_name=CFEK oraclesinfo $orclid | jq -r '[.registered | .[] | .publisher] | length')

for i in $(seq 0 $(( $len - 1 )))
do
#if [ $sub = ${pubsarray[$i]} ]
#then
echo "asd"
echo "${batonarray[$1]}"
komodo-cli -ac_name=CFEK oraclessamples $orclid ${batonarray[$i]} 1 | jq -r '.samples[0][0]' | jq '.'
#fi
done
