#!/vendor/bin/sh

TAG="collect_connsys_dump"

FW_VERSION=`getprop vendor.wlan.firmware.version`
SYS_VERSION=`getprop ro.vivo.product.version`

DUMP_HASH_CMM="// ## Firmware version\n\
// ## ----------------\n\
// ## VIVO|11102016|xiaolei.du|${FW_VERSION}\n\
// ## Description:  src_file_unknown.c:995:WLAN: (0x11102016): 0x99999\n\
// ## Arguments:    "

# Starts here
log -t ${TAG} "Start ${1} connsys dump..."

if [ "$1" == "clear" ]; then
    rm -rf /data/vendor/connsyslog/wifi/moredump*
    return
fi

#Routine for collecting EE dumps
if ls /data/vendor/connsyslog/wifi/moredump* 1> /dev/null 2>&1; then
    log -t ${TAG} "Collecting already started, return..."
    return
fi

# Reset last dump path
setprop "vendor.wifidump.prop.last_dump_path" ""

timestamp=`date '+%Y_%m_%d_%H_%M_%S'`
# Copy dumps to cache dir
dump_dir="moredump_${timestamp}"
mkdir /data/vendor/connsyslog/wifi/${dump_dir}
mkdir /data/vendor/connsyslog/wifi/${dump_dir}/bt
cp /data/vendor/connsyslog/bt/* /data/vendor/connsyslog/wifi/${dump_dir}/bt/
chmod 777 /data/vendor/connsyslog/bt/ -R
mv /data/vendor/connsyslog/wifi/combo_t32* /data/vendor/connsyslog/wifi/${dump_dir}
# Calculate hash and write hash file
if ls /data/vivo-common/circulatedlog/* 1> /dev/null 2>&1; then
    INTERNAL_IMEI=_int
elif ls /data/logData/modules/2900/* 1> /dev/null 2>&1; then
    INTERNAL_IMEI=_int
else
    INTERNAL_IMEI=""
fi
for file in `ls /data/vendor/connsyslog/wifi/${dump_dir}/*.xml`; do
    md5=($(md5sum ${file}))
    #log -t $TAG "md5sum: ${md5}"
    #log -t $TAG "${DUMP_HASH_CMM}${md5}"
    echo "${DUMP_HASH_CMM}${md5}_${SYS_VERSION}${INTERNAL_IMEI}" > /data/vendor/connsyslog/wifi/${dump_dir}/moredump_${timestamp}.cmm
done
# Save dmesg
product=`getprop ro.vivo.system.region.version`
KeyWord1="Trigger chip reset"
KeyWord2="assert@"
if [[ $(echo $product | grep "W30") != "" ]]; then
    log -t $TAG "product=$product. save $KeyWord only."
    dmesg | grep -E "$KeyWord1|$KeyWord2" > /data/vendor/connsyslog/wifi/${dump_dir}/kernel.log
else
    log -t $TAG "product=$product. save dmesg."
    dmesg > /data/vendor/connsyslog/wifi/${dump_dir}/kernel.log
fi
# Copy dmesg for bt
cp /data/vendor/connsyslog/wifi/${dump_dir}/kernel.log /data/vendor/connsyslog/bt/
# Save wifi fw log
cp -rf /data/debuglogger/connsyslog/fw/CsLog*/*.clog /data/vendor/connsyslog/wifi/${dump_dir}
cp -rf /data/debuglogger/connsyslog/fw/CsLog*/*.clog.curf /data/vendor/connsyslog/wifi/${dump_dir}
tar_file_path=/data/vendor/connsyslog/wifi/moredump_${timestamp}.tar.gz
tar -czf $tar_file_path -C /data/vendor/connsyslog/wifi/ .
chmod 777 $tar_file_path
setprop "vendor.wifidump.prop.last_dump_path" ${tar_file_path}
#/system/bin/am broadcast -a "com.vivo.intent.action.CLOUD_DIAGNOSIS" --ei "attr" 3 --ei "module" 3300 --es "data" "{\"moduleid\":\"3300\",\"eventId\":\"00059|012\",\"logpath\":\"${tar_file_path}\"}" com.bbk.iqoo.logsystem
