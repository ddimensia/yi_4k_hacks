# Yi 4k Action Camera Hacks
This repository contains information and hacks I've made to the Yi 4k Action camera based on the 1.10.9 firmware.  I started by looking at the information provided by https://github.com/irungentoo/Xiaomi_Yi_4k_Camera and found that many things referenced there don't appear to work on the latest firmware.

# Goal
Although I'd like to take this further my initial goal was to make the camera startup in a mode where it automatically starts live streaming.  The current method of hitting a touchscreen icon and then scanning a QR code doesn't work well for my use.  Any mechanism that provided minimal interaction to get it streaming was acceptible.

# What didn't work
There are a few things referenced online and in the [Xiamoi_Yi_4k_Camera](https://github.com/irungentoo/Xiaomi_Yi_4k_Camera) repository that didn't appear to work as expected with the latest (1.10.9) firmware.  I initially attempted to get the camera to attach to my wifi network as a client using a sta.conf file, that didn't appear to work although it did cause the camera to behave differently when starting wifi.  I also tried to execute commands via the ```t ipc rpc clnt exec1 '<cmd>'``` approach in a autoexec.ash file.  Although the autoexec.ash file was being executed I was never able to get a linux command to execute.

# What I learned
## General
I started poking around the linux squashfs partition to try and understand what gets run and how.  I stumbled across a few things of interest.  First, the wifi_start.sh script does attempt to read the sta.conf off the sd card which will cause it to attempt to run as a wifi client.  Second, there is a backdoor to run commands in the linux OS by placing a scripted named XCServer on the root of the SD card.  I believe this was setup for testing/debugging purposes but it allows you to have a script run on startup, it's important to have it execute the real XCServer command though as I believe this acts as part of the interconnect between the RTOS and linux.  Finally, I noticed that there was a usb_console.sh script that loads some kernel modules and redirects syslog to a usb serial terminal.

## Wifi client/station mode
The wifi startup scripts look for a sta.conf file on the root of the SD card.  It then runs dos2unix on it to fix potential line ending issues, I think this internally performs a 'mv' operation on the temporary file that is generated.  In my testing using 'mv' to rename a file doesn't work properly.  I think this is the first of the problems with how station mode works with the latest firmware.  After working around that problem I found that the wifi start script performs a site scan to look for the access point with the strongest signal and uses information from the scan to setup the auth method.  This information is written to a temporary wpa_supplicant.conf.  Something in this process causes the wlan0 device to have a problem.  The scan will succeed but when the network interface is attempted to be brought up by wpa_supplicant it fails.  This causes a subsequent dhcp lease attempt to fail because the interface is in a bad state.  I ended up pairing down the wifi startup scripts and got them to work reliably.

## RTMP streaming
It looks like a lot of the RTMP streaming setup is done on the linux side but not all.  I initially tried to initiate RTMP streaming from the usb_console by using the supplied rtmp.sh script and a hand rolled rtmp_info.conf file and combinations of using the camera in wifi station mode and hand executing commands.  In the end I was never able to get RTMP streaming running solely from the linux side of things.  I was able to get things to work on startup though, which was one of my goals.  The simplest method is to run `t ants rtmp_start` in the autoexec.ash file.  This will start the camera with the barcode reader waiting for a QR code without having to mess with the touchscreen menus.  To get it to fully startup automatically this is combined with a script that copies a user provided rtmp_info.conf file to /tmp and then pretends that the QR code was scanned successfully by calling `/usr/bin/SendToRTOS rtmp 1`.  This causes the RTOS to run the rtmp.sh script, enabling wifi, and then it calls the start_youtube_live.sh script which in turn connects to the RTOS remote api to perform streaming.

# Hacks
## XCServer replacement
The provided XCServer script, if placed on the root of your SD card, will be run at startup of the linux OS.  By default it will execute the real XCServer executable in the linux filesystem and then perform a few tasks based on other files it finds on the SD card.

## USB Console
If the XCServer script sees a `usb_console_enable.script` file then it will attempt to run a local usb_console.sh file, if it exists, or it will run the default usb_console.sh script provided in the firmware.  The usb_console.sh script in this repository simply disables the redirection of syslog to the serial terminal.  It also appears that if you don't connect to the terminal within 90 seconds it will timeout. That could possibly fixed by tweaking the usb_console.sh script but I haven't looked into that.

## Wifi client/station mode
