# Yi 4k Action Camera Hacks
This repository contains information and hacks I've made to the Yi 4k Action camera based on the 1.10.9 firmware.  I started by looking at the information provided by https://github.com/irungentoo/Xiaomi_Yi_4k_Camera and found that many things referenced there don't appear to work on the latest firmware.

# Goal
Although I'd like to take this further my initial goal was to make the camera startup in a mode where it automatically starts live streaming.  The current method of hitting a touchscreen icon and then scanning a QR code doesn't work well for my use.  Any mechanism that provided minimal interaction to get it streaming was acceptible.

# What didn't work
There are a few things referenced online and in the [Xiamoi_Yi_4k_Camera](https://github.com/irungentoo/Xiaomi_Yi_4k_Camera) repository that didn't appear to work as expected with the latest (1.10.9) firmware.  I initially attempted to get the camera to attach to my wifi network as a client using a sta.conf file, that didn't appear to work although it did cause the camera to behave differently when starting wifi.  I also tried to execute commands via the ```t ipc rpc clnt exec1 '<cmd>'``` approach in a autoexec.ash file.  Although the autoexec.ash file was being executed I was never able to get a linux command to execute.

# What I learned
I started poking around the linux squashfs partition to try and understand what gets run and how.  I stumbled across a few things of interest.  First, the wifi_start.sh script does attempt to read the sta.conf off the sd card which will cause it to attempt to run as a wifi client.  Second, there is a backdoor to run commands in the linux OS by placing a scripted named XCServer on the root of the SD card.  I believe this was setup for testing/debugging purposes but it allows you to have a script run on startup, it's important to have it execute the real XCServer command though as I believe this acts as part of the interconnect between the RTOS and linux.  Finally, I noticed that there was a usb_console.sh script that loads some kernel modules and redirects syslog to a usb serial terminal.

# Hacks
## XCServer replacement
The provided XCServer script, if placed on the root of your SD card, will be run at startup of the linux OS.  By default it will execute the real XCServer executable in the linux filesystem and then perform a few tasks based on other files it finds on the SD card.

## USB Console
If the XCServer script sees a `usb_console_enable.script` file then it will attempt to run a local usb_console.sh file, if it exists, or it will run the default usb_console.sh script provided in the firmware.  The usb_console.sh script in this repository simply disables the redirection of syslog to the serial terminal.  It also appears that if you don't connect to the terminal within 90 seconds it will timeout.
