#!/system/bin/sh

# log func
LOG_TAG="catsecplog_sh"
LOG_NAME="${0}:"
logi ()
{
    /system/bin/log -t $LOG_TAG -p i "$LOG_NAME $@"
}
logi "start catsecplog.sh"

# get current timestamp
timestamp=$(date "+%s%N")
milliseconds=$((${timestamp: -9} / 1000000))
dateNow=$(date "+%s$milliseconds")
logi $dateNow

# var define
MaxSize=$((10 * 1024 * 1024)) # 10M，单位为字节
ORIGIN_LOG_PATH=/data/vendor/Secp/logData/log
ZIP_LOG_PATH=/data/vendor/Secp/logData/uploadFiles
LOGSYSTEM_PATH=/data/logData/modules/5110
MAIN_LOG=$ORIGIN_LOG_PATH/main_log
KERNEL_LOG=$ORIGIN_LOG_PATH/kernel_log
secplogZipFilePath=$ZIP_LOG_PATH/secplog@$dateNow.tar.gz
secplogUploadFilePath=$ZIP_LOG_PATH/secplog@$dateNow.info
logSystemFilePath=/data/logData/modules/5110/secplog@$dateNow.info

# clear old files
logi "clear all files before cat"
rm -f $ZIP_LOG_PATH/*
logi "clear all files before cat done"

# cat main_log
timestampbegin=$(date "+%s%N")
/system/bin/logcat -d | /system/bin/grep -e SecpManager -e SecpCA \
 -e SecTee -e SecTeeCA \
 -e SyntheticPassword -e LockSettings \
 -e FileManagerHelper > $MAIN_LOG
timestampend=$(date "+%s%N")
costTime=$((timestampend - timestampbegin))
logi "time1: $costTime"

chmod 777 $MAIN_LOG
logi "cat main_log done"

if [ -f $MAIN_LOG ]
then
    logi "main_log is exist"

    filesize=$(stat -c%s "$MAIN_LOG") # 获取文件大小，单位为字节
    logi "fileSize: $filesize"
    if [ $filesize -gt $MaxSize ]; then
        logi "secplogUploadFile's size exceeds the maximum limit: $MaxSize"
        tail -c $MaxSize "$MAIN_LOG" > "$MAIN_LOG.tmp" # 保留文件后面部分，存储到临时文件中
        mv "$MAIN_LOG.tmp" "$MAIN_LOG" # 将临时文件重命名为原始文件
        logi "file has truncated."
    fi

    tar -czf  $secplogZipFilePath  -C /data/vendor/Secp/logData log
    mv $secplogZipFilePath $secplogUploadFilePath
    chmod 777 $secplogUploadFilePath
    cp $secplogUploadFilePath $LOGSYSTEM_PATH
else
   logi "main_log is not exist"
fi

setprop persist.vendor.vivo.catsecplog finish
logi "setprop done"

