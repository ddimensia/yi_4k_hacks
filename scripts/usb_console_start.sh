#!/bin/sh -x
# Start the USB Console if enabled
if [ -e /tmp/fuse_d/usb_console_enable.script ]; then
    echo "USB Console started from SD card ..." >> /tmp/fuse_d/autoexec.log
    echo device > /proc/ambarella/usbphy0
    modprobe usbcore
    modprobe ohci-hcd
    modprobe udc-core
    modprobe ambarella_udc
    modprobe libcomposite
    modprobe g_serial
    /sbin/getty -n -L 115200 /dev/ttyGS0 &
fi
