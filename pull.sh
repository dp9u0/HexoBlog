#!/bin/bash
echo "----------------------------------------" >> HexoBlogPull.log
echo $(date +%y_%m_%d_%H_%I_%T) >> HexoBlogPull.log  
echo "----------------------------------------" >> HexoBlogPull.log
echo "Begin Pull:" >> HexoBlogPull.log
git pull >> HexoBlogPull.log
echo "End Pull:" >> HexoBlogPull.log
echo "Begin hexo generate:" >> HexoBlogPull.log
hexo g >> HexoBlogPull.log
echo "End hexo generate:" >> HexoBlogPull.log
echo "----------------------------------------" >> HexoBlogPull.log
echo $(date +%y_%m_%d_%H_%I_%T) >> HexoBlogPull.log
echo "----------------------------------------" >> HexoBlogPull.log