#!/bin/bash

gps_tmp="$HOME/.komodo/gps.tmp"
gps_log="$HOME/.komodo/gps.log"
pass="$HOME/.komodo/gps.pass"
msg="$HOME/.komodo/msg.msg"
encmsg="$HOME/.komodo/msg.enc"
decmsg="$HOME/.komodo/msg.dec"
password=$(cat $pass)
if [[ ! -z $gps_tmp ]]; then
  touch $gps_tmp
fi
if [[ ! -z $gps_log ]]; then
  touch $gps_log
fi
if [[ $password != "" ]]; then
  echo "you need to create a password file in $HOME/.komodo/gps.pass"
fi
password=$(cat $pass)
echo "password: $password"
curl https://api.particle.io/v1/devices/events?access_token=fd5d0ee3766710a664d257371566294d34b304cb -N -s -o "$gps_tmp" &

while : 
do
	echo "waiting for gps string"
	line=$(  grep -a -m 1 data <( exec tail -f $gps_tmp ); kill $! 2> /dev/null)
	if [ "$line"!="" ]; then
		echo "$line" > $msg
		echo "line: $line"
		openssl enc -aes-256-cbc -in $msg -out $encmsg -a -A -k $password
		enc=$(cat $encmsg)
		echo "enc: $enc"
		echo "$line" >> "$gps_log"
		./send_GPS.py "$enc" &
		openssl enc -aes-256-cbc -d -in $encmsg -out $decmsg -a -A -k $password
		dec=$(cat $decmsg)
		echo "dec: $dec"
		line=""
		sleep 300
	fi
done
