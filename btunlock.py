#!/usr/bin/python
import os
import sys
import subprocess
import time
import socket
import threading
# This script needs that /usr/bin/l2ping and /bin/hciconfig be added to sudoers for current user
from os.path import basename
from gi.repository import Gtk, Gio, GObject, Gdk
from gi.repository import AppIndicator3 as appindicator

GObject.threads_init()

HomeDir = os.environ['HOME']
BaseDir = HomeDir + "/.btunlock"
IconDir = HomeDir + "/.icons"
DISABLEFILE = BaseDir + "/disable"
LOCKEDON_FILE = BaseDir + "/lockon"
LOCKEDOFF_FILE = BaseDir + "/lockoff"
isDisable = os.path.isfile(BaseDir + "/disable")
DAEMONPIDFILE = BaseDir + "/pid"
CONFIGFILE = BaseDir + "/config.ini"
LOCKFILE = BaseDir + "/locked"
DisFlag = False
LockFlag = False

# Utility funcs
##########################################################  

def notif_msg(msg):
    os.system("notify-send BTUnlock \"" + msg + "\"")
###########################################################

def killdaemon():
    global DAEMONPIDFILE
    # Get pid of the daemon and kill it
    try:
        f = open(DAEMONPIDFILE, "r")
        PID = f.read()
        f.close()
        PID = PID.rstrip('\n')
        os.kill(int(PID), signal.SIGTERM)
        os.system("kill " + PID)
    except:
        print ""
    
def cbk_quit(widget):
    global device
    global LOCKFILE
    global BaseDir
    global LOCKEDON_FILE
    global LOCKEDOFF_FILE
        # os.remove(PIDFILE)
    killdaemon()
    os.system("bash "+ BaseDir + "/btdisconn.sh " + device)
    try:
        os.remove(LOCKFILE)
    except:
        print ""
    try:
        os.remove(LOCKEDON_FILE)
    except:
        print ""
    try:
        os.remove(LOCKEDOFF_FILE)
    except:
        print ""

    Gtk.main_quit()

#--------------------------------------

def cbk_state(widget):
    global DISABLEFILE
    global device
    global LOCKFILE
    global LOCKEDON_FILE
    global LOCKEDOFF_FILE
    global BaseDir
    global IconDir
    global win
    if widget.get_active():
        #os.system("rm -f " + BaseDir + "/disable")
        try:
            os.remove(DISABLEFILE)
        except:
            print ""
        try:
            os.remove(BaseDir + "/locked")
        except:
            print ""
        notif_msg("Enabling daemon...")
        win.set_icon_from_file(IconDir+"/btunlock.png")
        os.system("bash "+BaseDir+"/btunlock_daemon.sh &")
    else:
        os.system("touch " + DISABLEFILE)
        time.sleep(2)
        killdaemon()
        win.set_icon_from_file(IconDir+"/btunlockdis.png")
        try:
            os.remove(LOCKFILE)
            os.remove(LOCKEDON_FILE)
            os.remove(LOCKEDOFF_FILE)
            os.system("bash "+ BaseDir + "/btdisconn.sh " + device)
        except:
            print ""
        notif_msg("Disabling daemon...1")       

# -------------------------------------

def chkdisabledaemon():
    global DISABLEFILE
    global LOCKFILE
    global BaseDir
    global device
    global status_item
    global DisFlag
    global LockFlag
    global ind
    global LOCKEDON_FILE
    global LOCKEDOFF_FILE

    while (True):
        time.sleep(2)
        if os.path.isfile(DISABLEFILE) and not DisFlag:
            DisFlag = True
            status_item.set_active( False )
            os.system("bash "+ BaseDir + "/btdisconn.sh " + device)
            ind.set_icon(IconDir+"/btunlockdis.png")
        if not os.path.isfile(DISABLEFILE) and DisFlag:
            DisFlag = False
            if os.path.isfile(LOCKEDOFF_FILE):
                ind.set_icon(IconDir+"/btunlock.png")
            if os.path.isfile(LOCKEDON_FILE):
                ind.set_icon(IconDir+"/btlock.png")
        if os.path.isfile(LOCKEDON_FILE) and not LockFlag:
            ind.set_icon(IconDir+"/btlock.png")
            LockFlag = True
        if os.path.isfile(LOCKEDOFF_FILE) and LockFlag:
            ind.set_icon(IconDir+"/btunlock.png")
            LockFlag = False

def get_lock(process_name):
    # Without holding a reference to our socket somewhere it gets garbage
    # collected when the function exits
    get_lock._lock_socket = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)

    try:
        get_lock._lock_socket.bind('\0' + process_name)
        print 'I got the lock'
    except socket.error:
        print 'lock exists'
        sys.exit()

# -------------------- Main ---------------------


#get_lock('btunlock')

device = subprocess.check_output("grep device " + CONFIGFILE + " | sed -e 's/device=//g'", shell=True)
device = device.rstrip('\n')

win=Gtk.Window()
if os.path.exists(DISABLEFILE):
    win.set_icon_from_file(IconDir+"/btunlockdis.png")
else:
    win.set_icon_from_file(IconDir+"/btunlock.png")
win.set_default_size(80, 80)
win.set_border_width(1)
win.set_decorated(False)
#win.set_keep_above(True)
win.set_opacity(0.7)

win.connect("delete-event", cbk_quit)

ind = appindicator.Indicator.new("BTUnlock", "btunlock", appindicator.IndicatorCategory.APPLICATION_STATUS)
ind.set_icon_theme_path(IconDir)
ind.set_status(appindicator.IndicatorStatus.ACTIVE)
ind.set_icon(IconDir+"/btunlock.png")

menu = Gtk.Menu()
status_item = Gtk.CheckMenuItem("Enable")
status_item.set_active( not (isDisable) )
status_item.connect("activate", cbk_state)
quit_item = Gtk.MenuItem("Quit")
quit_item.connect("activate", cbk_quit)

status_item.show()
quit_item.show()
menu.show_all()

menu.append(status_item)
menu.append(quit_item)

ind.set_menu(menu)

# Window content Header barcaracas
#hb = Gtk.HeaderBar()
#hb.set_show_close_button(True)
#hb.props.title = "Touch Helper"
#hb.set_subtitle(grp)
#win.set_titlebar(hb)

#awaybt = Gtk.Button()
#awaybt.connect("clicked", on_awaybt_clicked)
#icon = Gio.ThemedIcon(name="format-indent-more")
#image = Gtk.Image.new_from_gicon(icon, Gtk.IconSize.BUTTON)
#awaybt.add(image)
#hb.pack_start(awaybt)

#-----------Interface ----------------

vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)

#-----------------------------------------
# threading.Thread(target=chkdaemon).start()
#d = threading.Thread(target=chktrackwinsdaemon, name='Daemon')
#d.setDaemon(True)
#d.start()

#-----------------------------------------
# threading.Thread(target=chkdaemon).start()
d = threading.Thread(target=chkdisabledaemon, name='Daemon')
d.setDaemon(True)
d.start()


#win.show_all()
if ( not isDisable ):
    os.system("rm "  + BaseDir + "/locked")
    os.system("bash " + BaseDir + "/btunlock_daemon.sh &")
    os.system("python  " + HomeDir + "/bin/syslogwatcher.py tail -f " + BaseDir + "/btunlock.log &")
else:
    #os.system("notify-send BTUnlock \"Daemon Disabled!\"")
    notif_msg("Daemon Disabled")
Gtk.main()
