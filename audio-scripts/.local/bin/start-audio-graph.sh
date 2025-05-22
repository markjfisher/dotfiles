#!/bin/bash

carla $HOME/.config/audio/main.carxp > /dev/null 2>&1 &
sleep 1
nohup qpwgraph -a -x -m $HOME/.config/audio/pb1.qpwgraph > /dev/null 2>&1 &

