#!/bin/bash
LOG_FILE=~/HexoBlogAutoUpdate.log
echo "========================================" >> $LOG_FILE
echo $(date +%y_%m_%d_%H_%I_%T) >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE
if [ $1 ] ; then        
    echo "first argument is not empty : $1" >> $LOG_FILE
    TAR_DIR=$1 
    echo "use first argument as target dir : $TAR_DIR" >> $LOG_FILE
else
    echo "first argument is empty" >> $LOG_FILE  
    # use  ~/HexoBlog as the default dir    
    TAR_DIR=~/HexoBlog
    echo "use default dir as target dir : $TAR_DIR" >> $LOG_FILE
fi 
echo "----------------------------------------" >> $LOG_FILE
if [ -d $TAR_DIR ] ; then 
    echo "$TAR_DIR is a dir,try update" >> $LOG_FILE
    cd $TAR_DIR
    echo "++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
    echo "::::::::::::::begin git pull" >> $LOG_FILE
    git pull >> $LOG_FILE
    echo "++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
    echo "::::::::::::::begin  hexo clean" >> $LOG_FILE
    hexo clean >> $LOG_FILE
    echo "++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
    echo "::::::::::::::begin  hexo generate" >> $LOG_FILE
    hexo g >> $LOG_FILE
    echo "++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
    echo "::::::::::::::begin hexo deploy" >> $LOG_FILE
    hexo d >> $LOG_FILE
    echo "++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
    echo "::::::::::::::begin killall hexo" >> $LOG_FILE
    killall hexo >> $LOG_FILE
    echo "++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
    echo "::::::::::::::begin hexo server" >> $LOG_FILE
    hexo server &
    echo "++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
else
    echo "$TAR_DIR is not a dir,do nothing" >> $LOG_FILE
fi
echo "----------------------------------------" >> $LOG_FILE
echo $(date +%y_%m_%d_%H_%I_%T) >> $LOG_FILE
echo "========================================" >> $LOG_FILE