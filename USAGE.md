## Script usage

# Basics

Place the contents of this repository on the root of your camera's SD card.  The `autoexec.ash` run scripts on startup
that reside in the `scripts` directory.  Those scripts all look for a file on the root of the SD card that enable the
specific feature.  Not all features are compatible with one another, for instance, RTMP auto streaming is not compatible with
wifi client mode.

# RTMP Auto-streaming

To cause the Yi 4k to start streaming on startup rather than requiring you to mess with a QR code do the following:
1. Create a file named `autortmp_enable.script` on the root of your SD card.
2. Modify the `rtmp_info.conf` file on the root of your SD card to include the appropriate information.
3. Power on your camera with the SD card installed.  

The boot up process isn't super fast but what you should see is that upon starting up then camera will jump
into QR code scanning mode, after a few seconds it should quit scanning and attempt to connect to your wifi
hotspot and begin streaming.  

Effectively this script performs the same actions as if you manually initiated live streaming on the camera and provided
it with a QR code that contained the information in the `rtmp_info.conf` file.
