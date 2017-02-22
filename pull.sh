#!/bin/bash
echo $(date +%y_%m_%d_%H_%I_%T) >> HexoBlogPull.log     
echo "--------------------Begin--------------------" >> HexoBlogPull.log
git pull >> HexoBlogPull.log
echo "--------------------End--------------------" >> HexoBlogPull.log
echo $(date +%y_%m_%d_%H_%I_%T) >> HexoBlogPull.log