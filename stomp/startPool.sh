#!/bin/bash
/home/$USER/Knomp/install/redis-stable/src/redis-server /home/$USER/Knomp/install/redis-stable/redis.conf &
cd /home/$USER/kmd_pulp/stomp
./startStaked.sh &
komodod
sleep 60
cd /home/$USER/Knomp
nohup npm start &
#tail -f nohup.out
