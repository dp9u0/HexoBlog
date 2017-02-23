#!/bin/bash
# import path
DEFAULT_DIR=$HOME/HexoBlog
echo "========================================" 
echo $(date +%y_%m_%d_%H_%I_%T) 
echo "----------------------------------------" 
echo "HOME : $HOME"
if [ -f $HOME/.profile ] ; then
. ~/.profile
fi
echo "PATH : $PATH"
echo `whereis hexo`
echo "----------------------------------------" 
if [ $1 ] ; then        
    echo "first argument is not empty : $1" 
    TAR_DIR=$1 
    echo "use first argument as target dir : $TAR_DIR" 
else
    echo "first argument is empty"   
    # use $DEFAULT_DIR as the target dir    
    TAR_DIR=$DEFAULT_DIR
    echo "use default dir as target dir : $TAR_DIR" 
fi 
echo "----------------------------------------" 
if [ -d $TAR_DIR ] ; then 
    echo "$TAR_DIR is a dir,try update" 
    cd $TAR_DIR
    echo "++++++++++++++begin git pull++++++++++++" 
    git pull 
    echo "++++++++++++++begin  hexo clean+++++++++"
    hexo clean 
    echo "++++++++++++++begin  hexo generate+++++++"
    hexo g 
    echo "++++++++++++++begin hexo deploy+++++++++"
    hexo d 
    echo "++++++++++++++begin killall hexo++++++++" 
    killall hexo 
    echo "++++++++++++++begin hexo server+++++++++"
    hexo server &   
else
    echo "$TAR_DIR is not a dir,do nothing" 
fi
echo "----------------------------------------" 
echo $(date +%y_%m_%d_%H_%I_%T) 
echo "========================================" 