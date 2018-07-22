# Initiate the log file
echo 'Startup ...' > c:\autoexec.log

# Force wifi to be stopped on the device to avoid a race condition between
# the autortmp/wifi-client scripts that the normal wifi startup of the device
t app key stop_wifi

# USB console, shows up as /dev/cu.usbmodemXXXXX on OSX where XXXXX is a numeric value
# I imagine it shows up as a COM port on Windows
# Only runs if there is a usb_console_enable.script 
t ipc rpc clnt exec2 '/tmp/fuse_d/scripts/usb_console_start.sh &'

# Autortmp requires the QR code scanner to be started via 't ants rtmp_start',
# it will only run if there is an autortmp_enable.script file
t ipc rpc clnt exec2 '/tmp/fuse_d/scripts/autortmp_start.sh &'

# Wifi client is only runs if there is a wifi_client_enable.script file 
# and no autortmp_enable.script file
t ipc rpc clnt exec2 '/tmp/fuse_d/scripts/wifi_client_start.sh &'

# Initiate the QR code scanner, comment out if not using rtmp streaming
t ants rtmp_start > c:\.rtmp_start
