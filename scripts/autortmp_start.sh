#!/bin/sh
export WIFI_EN_GPIO=124

wait_mmc_add ()
{
    /usr/local/share/script/t_gpio.sh ${WIFI_EN_GPIO} 0
    /usr/local/share/script/t_gpio.sh ${WIFI_EN_GPIO} 1
    if [ -e /proc/ambarella/mmc_fixed_cd ]; then
        mmci=`grep mmc /proc/ambarella/mmc_fixed_cd |awk $'{print $1}'|cut -c 4|tail -n 1`
        echo "${mmci} 1" > /proc/ambarella/mmc_fixed_cd
    else
        echo 1 > /sys/module/ambarella_config/parameters/sd1_slot0_fixed_cd
    fi
    echo 24000000 > /sys/module/ambarella_sd/parameters/sdio_host_max_frequency
    echo 24000000 > /sys/kernel/debug/mmc0/clock
    n=0
    while [ -z "`ls /sys/bus/sdio/devices`" ] && [ $n -ne 30 ]; do
        n=$(($n + 1))
        sleep 0.1
    done
}

wait_wlan0 ()
{
    n=0
    ifconfig wlan0
    waitagain=$?
    while [ $waitagain -ne 0 ] && [ $n -ne 60 ]; do
        n=$(($n + 1))
        sleep 0.1
        ifconfig wlan0
        waitagain=$?
    done
}

setup_wifi() {
    if [ -e /sys/module/bcmdhd/parameters/g_txglom_max_agg_num ]; then
        echo 0 >/sys/module/bcmdhd/parameters/g_txglom_max_agg_num
    fi
    if [ "${WIFI_EN_GPIO}" != "" ] && [ -z "`ls /sys/bus/sdio/devices`" ]; then
        wait_mmc_add
    fi
    
    #check wifi mode
    /usr/local/share/script/load.sh "sta"

    waitagain=1
    if [ -n "`ls /sys/bus/sdio/devices`" ] || [ -e /sys/bus/usb/devices/*/net ]; then
        wait_wlan0
    fi
    if [ $waitagain -ne 0 ]; then
        echo "There is no WIFI interface!pls check wifi dirver or fw"
    fi
}

wait_for_kernelmodule_unload() {
    n=0
    lsmod | grep '^bcmdhd'
    waitagain=$?
    while [ $waitagain -ne 0 ] && [ $n -ne 10 ]; do
      n=$(($n + 1))
      sleep 1
      lsmod | grep '^bcmdhd'
      waitagain=$?
    done
    echo "Took $n seconds waiting for bcmdhd to be loaded ..." >> /tmp/fuse_d/autoexec.log

    n=0
    lsmod | grep '^bcmdhd'
    waitagain=$?
    while [ $waitagain -eq 0 ] && [ $n -ne 10 ]; do
      n=$(($n + 1))
      sleep 1
      lsmod | grep '^bcmdhd'
      waitagain=$?
    done
    echo "Took $n seconds waiting for bcmdhd to be unloaded ..." >> /tmp/fuse_d/autoexec.log
}

if [ -e /tmp/fuse_d/autortmp_enable.script ] && [ -e /tmp/fuse_d/rtmp_info.conf ]; then
    # There appears to be a race condition with the RTOS setting up the wifi kernel
    # module.  We need to wait for it to be loaded and unloaded so that we don't
    # hang the system
    wait_for_kernelmodule_unload

    echo "Auto starting rtmp stream ..." >> /tmp/fuse_d/autoexec.log
    n=0
    while [ ! -e /tmp/fuse_d/.rtmp_start ] && [ $n -ne 10 ]; do
        n=$(($n + 1))
        sleep 1
    done
    if [ $n -eq 10 ]; then
        echo "Failed to find .rtmp_start file in $n seconds, exiting ..." >> /tmp/fuse_d/autoexec.log
        /usr/bin/SendToRTOS rtmp 4
        exit 1
    fi
    cp -rf /tmp/fuse_d/rtmp_info.conf /tmp/rtmp_info.conf
    setup_wifi
    /usr/bin/SendToRTOS rtmp 1
fi
