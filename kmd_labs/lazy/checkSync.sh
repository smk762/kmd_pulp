#!/bin/bash

# yet to test version checking - "longest chain can get lost quite easily on early chains, might need some extra check 
# @webworker01 has some code that checks explorers heights, which might be a good way to go, but we have to have explorers up first.


	ac_name=$1
	if [ $ac_name == "KMD" ]; then
		acName_flag=""
	else	
		acName_flag="-ac_name=$ac_name"
	fi
	while [ -z $blocks ]; do
		info=$(echo $(komodo-cli $acName_flag getinfo)) > /dev/null 2>&1
		blocks=$(echo ${info} | jq -r '.blocks')
		longestchain=$(echo ${info} | jq -r '.longestchain')
		#echo "$ac_name longestchain: $longestchain"
		#echo "$ac_name blocks: $blocks"
		if [ -z $longestchain ]; then
			echo "[$ac_name not syncronised, checking again in 20 seconds"
	    	sleep 20			
		elif [ $longestchain != 0 ]; then
			if [ $blocks == $longestchain ]; then
				break 2;
			elif [ $blocks -eq 0 ]; then
				echo "Incompatible Komodo version. Check Discord to confirm you're on the right repo."
				exit 0;
			else
				progress=$(echo blocks/longestchain|bc)
				echo "[$ac_name not syncronised ($progress), checking again in 20 seconds"
		    	sleep 20
		    fi
		fi
	done
	echo "[$ac_name syncronised on block ${blocks}]"