#!/bin/bash
# Fetch assetchains.json
wget -qO assetchains.json https://raw.githubusercontent.com/StakedChain/StakedNotary/master/assetchains.json
overide_args="$@"

/home/$USER/Knomp/install/listassetchainparams.py | while read args; do
  komodod $args $overide_args -pubkey=$pubkey & #> /dev/null 2>&1 &
  sleep 2
done
komodod
# Start assets

