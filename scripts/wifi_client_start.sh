#!/bin/sh

export CHIP_TYPE=43340
export WIFI_MAC=`cat /tmp/wifi0_mac`

check_country_setting_channel()
{
	case $AP_COUNTRY in
		HK | ID | MY | UA | IN | MX | VN | BY | MM | BD | IR)
		wl country XZ/0
		;;
		ES | FR | PL | DE | IT | GB | PT | GR | NL | HU | SK | NO | FI)
		wl country EU/0
		;;
		CA)
		wl country CA/2
		;;
		CN)
		wl country CN
		;;
		CZ)
		wl country CZ
		;;
		US)
		wl country US
		;;
		RU)
		wl country RU
		;;
		JP)
		wl country JP/5
		;;
		KR)
		wl country KR/24
		;;
		IL)
		wl country IL
		;;
		SE)
		wl country SE
		;;
		SG)
		wl country SG
		;;
		TR)
		wl country TR/7
		;;
		TW)
		wl country TW/2
		;;
		AU)
		wl country AU
		;;
		BR)
		wl country BR
		;;
		TH)
		wl country TH
		;;
		PH)
		wl country PH
		;;
	esac
}

wait_ip_done ()
{
	n=0
	wlan0_ready=`ifconfig wlan0|grep "inet addr"`
	while [ "${wlan0_ready}" == "" ] && [ $n -ne 10 ]; do
		wlan0_ready=`ifconfig wlan0|grep "inet addr"`
		n=$(($n + 1))
		sleep 1
	done

	if [ "${wlan0_ready}" != "" ]; then
		#send net status update message (Network ready, STA mode)
		if [ -x /usr/bin/SendToRTOS ]; then
			/usr/bin/SendToRTOS net_ready 1
		elif [ -x /usr/bin/boot_done ]; then
			boot_done 1 2 1
		fi
	else
		echo "Cannot get IP within 10 sec, skip boot_done"
	fi
}

mmc_setup ()
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

client_start() {
    echo "Attempting to start wifi client ..." >> /tmp/fuse_d/autoexec.log
    driver=nl80211
    check_country_setting_channel
    killall wpa_supplicant

    # Use a provided wpa_supplicant.conf if available
    if [ -e /tmp/fuse_d/wpa_supplicant.conf ]; then
            echo "Using provided wpa_supplicant.conf ..." >> /tmp/autoexec.log
    	cp /tmp/fuse_d/wpa_supplicant.conf /tmp
    	exit 0
    else 
        echo "Generating wpa_supplicant.conf from wifi_sta.conf ..." >> /tmp/autoexec.log
        echo "ctrl_interface=/var/run/wpa_supplicant" > /tmp/wpa_supplicant.conf
        echo "network={" >> /tmp/wpa_supplicant.conf
        echo "ssid=\"${ESSID}\"" >> /tmp/wpa_supplicant.conf
    
        if [ "${AUTH_TYPE}" == "WPA" ] || [ "${AUTH_TYPE}" == "WPA2" ]; then
            echo "key_mgmt=WPA-PSK" >> /tmp/wpa_supplicant.conf
    
            if [ "${AUTH_TYPE}" == "WPA2" ]; then
                echo "proto=WPA2" >> /tmp/wpa_supplicant.conf
            else
                echo "proto=WPA" >> /tmp/wpa_supplicant.conf
            fi
    
            echo "psk=\"${PASSWORD}\"" >> /tmp/wpa_supplicant.conf
        fi
    
        if [ "${AUTH_TYPE}" == "WEP" ]; then
            echo "key_mgmt=NONE" >> /tmp/wpa_supplicant.conf
            echo "wep_key0=${PASSWORD}" >> /tmp/wpa_supplicant.conf
            echo "wep_tx_keyidx=0" >> /tmp/wpa_supplicant.conf
        fi
    
        if [ "${AUTH_TYPE}" == "NONE" ]; then
            echo "key_mgmt=NONE" >> /tmp/wpa_supplicant.conf
        fi
    
        echo "}" >> /tmp/wpa_supplicant.conf
    
        if [ -e /sys/module/bcmdhd ]; then
            echo "p2p_disabled=1" >> /tmp/wpa_supplicant.conf
            if [ "`uname -r`" != "2.6.38.8" ]; then
                echo "wowlan_triggers=any" >> /tmp/wpa_supplicant.conf
            fi
        fi
        if [ -e /sys/module/8189es ] || [ -e /sys/module/8723bs ]; then
            if [ "`uname -r`" != "2.6.38.8" ]; then
                echo "wowlan_triggers=any" >> /tmp/wpa_supplicant.conf
            fi
        fi
    fi
    
    wpa_supplicant -D${driver} -iwlan0 -c/tmp/wpa_supplicant.conf -B >> /tmp/fuse_d/autoexec.log
    if [ "$STA_DEVICE_NAME" != " " ]; then
        udhcpc -i wlan0 -x hostname:"${STA_DEVICE_NAME}" -A 1 -b >> /tmp/fuse_d/autoexec.log
    else
        udhcpc -i wlan0 -x hostname:'XiaoYi SportCam 2' -A 1 -b >> /tmp/fuse_d/autoexec.log
    fi
    wait_ip_done
}

if [ ! -e /tmp/fuse_d/autortmp_enable.script ] && [ -e /tmp/fuse_d/wifi_client_enable.script ] && [ -e /tmp/fuse_d/wifi_sta.conf ]; then
    # There appears to be a race condition with the RTOS setting up the wifi kernel
    # module.  We need to wait for it to be loaded and unloaded so that we don't
    # hang the system
    wait_for_kernelmodule_unload

    echo "Enabling wifi client ..." >> /tmp/fuse_d/autoexec.log
    conf=`cat /tmp/fuse_d/wifi_sta.conf | grep -Ev "^#"`
    export `echo "${conf}"|grep -v PASSW|grep -v SSID|grep -vI $'^\xEF\xBB\xBF'`
    export WIFI_EN_GPIO=124
    export AP_COUNTRY=`echo "${conf}" | grep COUNTRY_CODE | cut -c 14-`
    export PASSWORD=`echo "${conf}" | grep PASSWORD | cut -c 10-`
    export ESSID=`echo "${conf}" | grep SSID | cut -c 6-`
    export STA_DEVICE_NAME=`echo "${conf}" | grep DEVICE_NAME | cut -c 13-`
    export AUTH_TYPE=`echo "${conf}" | grep AUTH_TYPE | cut -c 11-`

    if [ -e /sys/module/bcmdhd/parameters/g_txglom_max_agg_num ]; then
        echo 0 >/sys/module/bcmdhd/parameters/g_txglom_max_agg_num
    fi
    
    if [ "${WIFI_EN_GPIO}" != "" ] && [ -z "`ls /sys/bus/sdio/devices`" ]; then
        mmc_setup
    fi
    
    /usr/local/share/script/load.sh sta
    
    waitagain=1
    if [ -n "`ls /sys/bus/sdio/devices`" ] || [ -e /sys/bus/usb/devices/*/net ]; then
        wait_wlan0
    fi
    if [ $waitagain -ne 0 ]; then
        echo "There is no WIFI interface!pls check wifi dirver or fw" >> /tmp/fuse_d/autoexec.log
        exit 1
    fi
    
    echo "Found  WIFI interface!" >> /tmp/fuse_d/autoexec.log
    client_start
fi
