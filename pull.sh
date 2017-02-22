#!/bin/bash
echo $(date +%y_%m_%d_%H_%I_%T) >> HexoBlogPull.log     
echo "Begin Pull" >> HexoBlogPull.log
git pull >> HexoBlogPull.log
echo $(date +%y_%m_%d_%H_%I_%T) >> HexoBlogPull.log