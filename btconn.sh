#!/bin/bash
CONFFILE=~/.btunlock/config.ini
DEVICE=$1
if [[ -z $DEVICE ]];then
DEVICE=`grep device $CONFFILE | sed -e 's/device=//g'`
if [[ -z $DEVICE ]];then
echo Could not get device mac from config file $CONFFILE
exit 2
fi
fi
bluetoothctl << EOF > /dev/null
power on
connect $DEVICE
EOF
exit 0
