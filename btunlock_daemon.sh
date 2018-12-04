#!/bin/bash
# Copied from Steven on http://gentoo-wiki.com/Talk:TIP_Bluetooth_Proximity_Monitor
# These are the sections you'll need to edit

# This script needs that /usr/bin/l2ping and /bin/hciconfig be added to sudoers for current user

# How often to check the distance between phone and computer in seconds
CHECK_INTERVAL=60
DISABLE_FILE=~/.btunlock/disable
LOCKEDON_FILE=~/.btunlock/lockon
LOCKEDOFF_FILE=~/.btunlock/lockoff
PIDFILE=~/.btunlock/pid
CONFFILE=~/.btunlock/config.ini
LOCKFILE=~/.btunlock/locked
NOTIF_CMD=
HCITOOL=/usr/bin/hcitool
LOGFILE=~/.btunlock/btunlock.log

rm -f $LOCKEDON_FILE
rm -f $LOCKEDOFF_FILE

DEVICE=`grep device $CONFFILE | sed -e 's/device=//g'`
if [[ -z $DEVICE ]];then
echo Could not get device mac from config file $CONFFILE
exit 2
fi

# The RSSI threshold at which a phone is considered far or near
#THRESHOLD=-4
THRESHOLD=`grep threshold $CONFFILE | sed -e 's/threshold=//g'`
if [[ -z $THRESHOLD ]];then
THRESHOLD=-4
fi

#Locking mechanism
tempfile=$(mktemp /tmp/btlock.XXXX)
if ! ln $tempfile $LOCKFILE ; then
    echo "Daemon already running. Quitting..."
    notify-send  BTUnlock "Daemon already running!"
    exit 5
fi

# The command to run when your phone gets too far away
FAR_CMD=`grep farcmd $CONFFILE | sed -e 's/farcmd=//g'`
if [[ -z $FAR_CMD ]];then
FAR_CMD='gnome-screensaver-command -l'
fi

# The command to run when your phone is close again
NEAR_CMD=`grep nearcmd $CONFFILE | sed -e 's/nearcmd=//g'`
if [[ -z $NEAR_CMD ]];then
NEAR_CMD='gnome-screensaver-command -d'
fi


connected=0
echo $$ > $PIDFILE

function msg {
    echo "`date`: $1" >> "$LOGFILE"
}

function check_connection {
    connected=0;
    #found=0
    #for s in `$HCITOOL con`; do
    #     if [[ "$s" == "$DEVICE" ]]; then
    #         found=1;
    #     fi
    # done
    # if [[ $found == 1 ]]; then
    if [ "`$HCITOOL con | grep -c $DEVICE`" -eq 1 ]; then
        connected=1;
       
    else
       msg 'Attempting connection...'
       bash ~/.btunlock/btconn.sh $DEVICE
       sleep 4
        #if [ "`$HCITOOL con | grep -c $DEVICE`" -eq 1 ]; then
        if [ "`sudo l2ping -c 1 $DEVICE | grep -c Ping 2> /dev/null`" -eq 1 ]; then
            msg 'Connected.'
            connected=1
            
        else
            #if [ "`sudo l2ping -c 1 $DEVICE | grep -c Ping 2> /dev/null`" -eq 1 ]; then
            #    bash ~/.btunlock/btconn.sh $DEVICE
            #    sleep 8
            #    if [ "`$HCITOOL con | grep -c $DEVICE`" -eq 1 ]; then
            #        msg 'Back to Connected.'
            #        connected=1
            #    else
                    msg "ERROR: 2nd try Could not connect to device $DEVICE."
                    connected=0
                    
            #    fi
            
            #fi
        fi
    fi
}

msg "========= Starting daemon... =============================================="
if [ -f $DISABLE_FILE ];then
    msg "Disable file found. Exiting..."
    exit 3
fi
if [ "`hciconfig | grep -c DOWN 2> /dev/null`" -eq 1 ]; then
    msg "Bluetooth is down. Activating it..."
    sudo hciconfig hci0 up
    sleep 2
fi
shut_cont=0
check_connection
while [[ $connected -eq 0 ]]; do
    check_connection
shut_cont=$(echo "$shut_cont + 1" | bc)
    if [ $shut_cont -gt 5 ];then 
        touch $DISABLE_FILE
        sudo hciconfig hci0 down
        exit 0
    fi
    sleep 300    
done

name=`$HCITOOL name $DEVICE`
msg "Monitoring proximity of \"$name\" [$DEVICE]";
#Mark connected to change indicator icon
touch $LOCKEDOFF_FILE
rm -f $LOCKEDON_FILE

state="near"
while /bin/true; do

    if [ -f $DISABLE_FILE ];then
        msg "Disable file found. Exiting..."
        bash ~/.btunlock/btdisconn.sh $DEVICE
        exit 3
    fi

    check_connection

    if [[ $connected -eq 1 ]]; then
        rssi=$($HCITOOL rssi $DEVICE | sed -e 's/RSSI return value: //g')

        if [[ $rssi -le $THRESHOLD ]]; then
            if [[ "$state" == "near" ]]; then
                msg "*** Device \"$name\" [$DEVICE] has left proximity"
                #notify-send  BTUnlock "Device $name is far. Locking session!"
                state="far"
                #if [[ ! -z $NOTIF_CMD ]]; then
#$NOTIF_CMD "\"BTUnlock: Device $name is far. Locking session!\""
#                fi
            #Mark to change indicator icon
                rm -f $LOCKEDOFF_FILE
                touch $LOCKEDON_FILE
                
                msg "     Running far command $FAR_CMD"
$FAR_CMD > /dev/null 2>&1
            fi
        else
            if [[ $rssi == "" ]];then
                msg "Rssi is empty"
            elif [[ "$state" == "far" && $rssi -ge $[$THRESHOLD+2] ]]; then
                msg "*** Device \"$name\" [$DEVICE] is within proximity"
                state="near"
                rm -f $LOCKEDON_FILE                
                touch $LOCKEDOFF_FILE
            #Mark to change indicator icon
                if [ `gnome-screensaver-command -q | grep -c ' active'` -eq 1 ];then
                    
                    msg "====Running near command $NEAR_CMD"
$NEAR_CMD > /dev/null 2>&1
                fi
                #sleep $CHECK_INTERVAL
            fi
        fi

    else  #Not connected in check_connection locking session
        if [[ "$state" == "near" ]]; then
            msg "*** Device \"$name\" [$DEVICE] has left proximityyyy"
            rssi=-100
            state="far"
            rm -f $LOCKEDOFF_FILE
            touch $LOCKEDON_FILE
            msg "****Running $FAR_CMD"
            $FAR_CMD > /dev/null 2>&1
        fi
    fi
    if [[ $state == "far" ]];then
        CHECK_INTERVAL=7
    else 
        CHECK_INTERVAL=60  #DEBUG
    fi

    msg "state = $state, RSSI = $rssi, interval = $CHECK_INTERVAL"

#    msg "Sleeping $CHECK_INTERVAL"
    sleep $CHECK_INTERVAL
done
