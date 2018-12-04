#!/bin/bash

BASEDIR=~/.btunlock
mkdir $BASEDIR 
rm -f $BASEDIR/*sh
#cp *sh ~/.btunlock
ln -s $PWD/btconn.sh $BASEDIR/btconn.sh
ln -s $PWD/btdisconn.sh $BASEDIR/btdisconn.sh
ln -s $PWD/btunlock_daemon.sh $BASEDIR/btunlock_daemon.sh
cp images/* ~/.icons
cp config.ini ~/.btunlock
echo NEED TO ADD /usr/bin/l2ping,/bin/hciconfig TO /etc/sudoers !!!
