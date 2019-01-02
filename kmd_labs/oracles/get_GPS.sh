#!/bin/bash
pass="$HOME/.komodo/gps.pass"
enc="$HOME/.komodo/tmp.enc"
dec="$HOME/.komodo/tmp.dec"
password=$(cat $pass)
./read_oracle.py
encMsgs=($(cat $HOME/.komodo/gps.enc))
for encMsg in ${encMsgs[@]}; do
	echo $encMsg > $enc
	openssl enc -aes-256-cbc -d -in $enc -out $dec -a -A -k $password
	cat $dec
done