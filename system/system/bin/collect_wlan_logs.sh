#!/system/bin/sh

TAG="cnss_collect_wlan_logs"
BASE_DIR="/data/vivo-common/circulatedlog/"

function dump_sys_service {
    log -t ${TAG} "dumpsys start ${1}"
    dumpsys wifi > "${1}/wifi.dump"
    chmod 774 ${1}/wifi.dump
    dumpsys connectivity > "${1}/connectivity.dump"
    chmod 774 ${1}/connectivity.dump
    #dumpsys netd > "${1}/netd.dump"
    dumpsys wificond > "${1}/wificond.dump"
    chmod 774 ${1}/wificond.dump
    dumpsys network_management > "${1}/network_management.dump"
    chmod 774 ${1}/network_management.dump
    dmesg > "${1}/dmesg.log"
    chmod 774 ${1}/dmesg.log
    getprop > "${1}/properties.log"
    chmod 774 ${1}/properties.log
    logcat -b main -d -t 100000 > "${1}/logcat.log"
    chmod 774 ${1}/logcat.log
}

log -t ${TAG} "started"

PLAT_ARR=("MTK6991" "MTK6989")
platform=`getprop ro.vivo.product.platform`
ics_enable=`getprop vendor.connsysfw.ics.enable`
need_set_ics="1"

if echo "${PLAT_ARR[@]}" | grep -w "$platform">/dev/null; then
    if [ "$ics_enable" == "1" ]; then
        need_set_ics="0"
    fi
fi

log -t $TAG "platform: $platform, ics state: $ics_enable, need: $need_set_ics"

if [ "$1" == "onoff" ]; then
    status=`getprop persist.sys.circulated_wlan_logs`
    log -t $TAG "Circulated wlan logs enabled state: $status"
    if [ "$status" == "1" ]; then
        echo "v_ds,1" > data/connsyslog/connsyslog_serv_fifo
        sleep 0.5
        if [ "$need_set_ics" == "1" ];then
            iwpriv wlan0 driver "sniffer=2-0-0-0-2-0-0-0-0-0"
            iwpriv wlan0 driver "sniffer=2-0-0-0-2-1-0-0-0-0"
        fi
    else
        if [ "$need_set_ics" == "1" ];then
            iwpriv wlan0 driver "sniffer=2-0-0-0-2-0-0-0-0-0"
            iwpriv wlan0 driver "sniffer=2-0-0-0-2-1-0-0-0-0"
            sleep 0.5
        fi
        echo "v_dp,1" > data/connsyslog/connsyslog_serv_fifo
    fi
    return
fi

# Starts here
# 0:WIFI_DISCONNECT, 1:NO_INTERNET, 2:GAME_DELAY, 4:LOSS_WITH_RETRY
# 8:WIFI_2_WIFI_FAILURE, 10:CONNECTION_FAILURE, 13: TX_HANG, 14:HIGH_TX_DELAY
REASON_ARR=(0 1 2 4 8 10 13 14)
reason=`getprop sys.vivo.wlan_log_trigger_reason`
log -t ${TAG} "Reason code is $reason, Trigger log dump..."

if echo "${REASON_ARR[@]}" | grep -w "$reason">/dev/null; then
    if [ "$need_set_ics" == "1" ];then
        # Start ICS log with TRx mode
        iwpriv wlan0 driver "sniffer=2-1-0-0-2-0-0-0-0-0"
        iwpriv wlan0 driver "sniffer=2-1-0-0-2-1-0-0-0-0"
        iwpriv wlan0 driver "sniffer=2-2-0-5-0-0-0-0-0-0"
        iwpriv wlan0 driver "sniffer=2-2-0-5-0-1-0-0-0-0"
    fi

    # To trigger icmp packets sending by driver
    # Log packaging in framework will wait for 10s, so ping will wait 5s
    GATEWAY_IP=`ip route show table wlan0 | grep 'default via'|awk '{print$3}'`
    log -t ${TAG} "Get gateway ip = $GATEWAY_IP"
    if echo $GATEWAY_IP | grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$">/dev/null; then
        ping -i 0.5 -w 4 $GATEWAY_IP
        sleep 1
    else
        sleep 5
    fi

    if [ "$need_set_ics" == "1" ];then
        # disable ics log
        iwpriv wlan0 driver "sniffer=2-0-0-0-2-0-0-0-0-0"
        iwpriv wlan0 driver "sniffer=2-0-0-0-2-1-0-0-0-0"
    fi
fi


rm -rf /data/vivo-common/circulatedlog/*
dump_sys_service $BASE_DIR
# cp FW logs
LATEST_FW_DIR=$(ls -td /data/debuglogger/connsyslog/fw/CsLog_* | head -1)
cp -rf `ls -t ${LATEST_FW_DIR}/WIFI_FW_*.clog | head -1` /data/vivo-common/circulatedlog/
cp -rf `ls -t ${LATEST_FW_DIR}/WIFI_FW_*.clog.curf | head -1` /data/vivo-common/circulatedlog/
cp -rf `ls -t ${LATEST_FW_DIR}/BT_FW_*.clog | head -1` /data/vivo-common/circulatedlog/
cp -rf `ls -t ${LATEST_FW_DIR}/BT_FW_*.clog.curf | head -1` /data/vivo-common/circulatedlog/
cp -rf `ls -t ${LATEST_FW_DIR}/ICS_FW_*.clog | head -1` /data/vivo-common/circulatedlog/
cp -rf `ls -t ${LATEST_FW_DIR}/ICS_FW_*.clog.curf | head -1` /data/vivo-common/circulatedlog/

chmod 0777 /data/vivo-common/circulatedlog/*.clog
chmod 0777 /data/vivo-common/circulatedlog/*.clog.curf
