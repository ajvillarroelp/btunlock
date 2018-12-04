#!/bin/bash
bluetoothctl << EOF > /dev/null
power on
EOF
exit 0
