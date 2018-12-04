#!/bin/bash
bluetoothctl << EOF > /dev/null
power off
EOF
exit 0
