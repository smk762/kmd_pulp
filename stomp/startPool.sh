#!/bin/bash
/home/$USER/Knomp/install/redis-stable/src/redis-server /home/$USER/Knomp/install/redis-stable/redis.conf &
cd /home/$USER/kmd_pulp/Staked/lazy
./startStaked.sh &
sleep 120
cd /home/$USER/Knomp
nohup npm start &
#tail -f nohup.out
