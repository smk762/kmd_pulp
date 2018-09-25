#!/bin/bash
/home/$USER/Knomp/install/redis-stable/src/redis-server /home/$USER/Knomp/install/redis-stable/redis.conf &
cd /home/$USER/Knomp/install
./startStaked.sh &
komodod
sleep 60
cd ..
nohup npm start &
#tail -f nohup.out
