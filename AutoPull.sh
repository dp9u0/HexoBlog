#!/bin/bash
echo "----------------------------------------" >> ~/HexoBlogPull.log
echo $(date +%y_%m_%d_%H_%I_%T) >> ~/HexoBlogPull.log
echo "----------------------------------------" >> ~/HexoBlogPull.log
cd ~/HexoBlog
echo "----------Begin Git Pull----------" >> ~/HexoBlogPull.log
git pull >> ~/HexoBlogPull.log
echo "----------End Git Pull----------" >> ~/HexoBlogPull.log
echo "----------Begin hexo g----------" >> ~/HexoBlogPull.log
hexo g >> ~/HexoBlogPull.log
echo "----------End hexo g----------" >> ~/HexoBlogPull.log
echo "----------------------------------------" >> ~/HexoBlogPull.log
echo $(date +%y_%m_%d_%H_%I_%T) >> ~/HexoBlogPull.log
echo "----------------------------------------" >> ~/HexoBlogPull.log
echo "========================================" >> ~/HexoBlogPull.log