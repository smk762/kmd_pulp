#!/bin/bash

# Any coins you would like to skip go here
# -ac_perc coins are unminable at this stage
declare -a skip=("BEER" "PIZZA" "STAKEDUH" "STAKEDCF")

# Stratum port to start
stratumport=3030

coinsdir=/home/$USER/Knomp/coins
poolconfigdir=/home/$USER/Knomp/pool_configs

coinstpl=/home/$USER/Knomp/coins.template
pooltpl=/home/$USER/Knomp/poolconfigs.template

ufwenablefile=/home/$USER/Knomp/stratufwenable
ufwdisablefile=/home/$USER/Knomp/stratufwdisable
$ufwdisablefile

cointemplate=$(<$coinstpl)
pooltemplate=$(<$pooltpl)

rm -rf $coinsdir
rm -rf $poolconfigdir

mkdir -p $coinsdir
mkdir -p $poolconfigdir

#clean old up
rm $ufwenablefile
rm $ufwdisablefile
touch $ufwenablefile
touch $ufwdisablefile


#Get Asset Chain Names from json file
ac_json=$(curl https://raw.githubusercontent.com/blackjok3rtt/StakedNotary/master/assetchains.json 2>/dev/null)
for row in $(echo "${ac_json}" | jq -c -r '.[]'); do
  _jq() {
    echo ${row} | jq -r ${1}
  }
  chain=$(_jq '.ac_name')

  #Compare Asset Chain Names from json file to skip list
  if [[ " ${skip[@]} " =~ " ${chain} " ]]; then
        pointless=0
  else
  	# todo: better path
	if [ ! -f ~/kmd_pulp/stomp/wallets/.${chain}_wallet ]; then
	    echo -e "\e[91m ** Addresses not yet set, run ./genaddr.sh first ** \e[39m"
	else
	    walletaddress=$(cat ~/kmd_pulp/stomp/wallets/.${chain}_wallet | jq  -r '.addr')
	    echo Configuring $chain with address: ${walletaddress}
	    string=$(printf '%08x\n' $(komodo-cli -ac_name=$chain getinfo | jq '.magic'))
	    magic=${string: -8}
	    magicrev=$(echo ${magic:6:2}${magic:4:2}${magic:2:2}${magic:0:2})
	    p2pport=$(komodo-cli -ac_name=$chain getinfo | jq '.p2pport')
	    thisconf=$(<~/.komodo/$chain/$chain.conf)

	    rpcuser=$(echo $thisconf | grep -Po "rpcuser=(\S*)" | sed 's/rpcuser=//')
	    rpcpass=$(echo $thisconf | grep -Po "rpcpassword=(\S*)" | sed 's/rpcpassword=//')
	    rpcport=$(echo $thisconf | grep -Po "rpcport=(\S*)" | sed 's/rpcport=//')
	    echo "$cointemplate" | sed "s/COINNAMEVAR/$chain/" | sed "s/MAGICREVVAR/$magicrev/" > $coinsdir/$chain.json
	    echo "$pooltemplate" | sed "s/P2PPORTVAR/$p2pport/" | sed "s/COINNAMEVAR/$chain/" | sed "s/WALLETADDRVAR/$walletaddress/" | sed "s/STRATUMPORTVAR/$stratumport/" | sed "s/RPCPORTVAR/$rpcport/" | sed "s/RPCUSERVAR/$rpcuser/" | sed "s/RPCPASSVAR/$rpcpass/" > $poolconfigdir/$chain.json

	    echo "sudo ufw allow $stratumport comment 'Stratum $chain'" >> $ufwenablefile
	    echo "sudo ufw delete allow $stratumport" >> $ufwdisablefile
	    let "stratumport = $stratumport + 1"
	fi
  fi
done

chmod +x $ufwenablefile
chmod +x $ufwdisablefile
$ufwenablefile
