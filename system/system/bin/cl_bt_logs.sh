#!/system/bin/sh

TAG="vivo_cl_bt_logs"

# This path should be synced with defination in cnss diag
#BASE_DIR="/sdcard/cache/bt_logs/"
#BASE_DIR="/data/misc/bluetooth/logs/"
BASE_DIR="/data/logData/modules/bt_log_tmp/"
# this should be sync with bt_snoop.c's path
INNER_BT_SNOOP_FILE_PATH="/data/misc/bluetooth/logs"
SDCARD_BT_SNOOP_FILE_PATH="/data/bbklog/bt_log"
CORE_DUMP_FILE_PATH="/data/vendor/connsyslog/bt"
VENDOR_DB_FILE_PATH="/data/vendor/aee_exp"
POST_FIX="1.gz"

# Put zipped file to specified location and will be uploaded
MODULE_LOCATION="/data/logData/modules/"
DEST_LOCATION="/data/logData/modules/4000/"
SLEEP_DURATION=15
SLEEP_HW_ERR_DURATION=45

# Relative props
bt_trigger_hash_addr="sys.vivo.bt_log_trigger_hash_addr"
bt_trigger_reason_prop="sys.vivo.bt_log_trigger_reason"
bt_trigger_err_desc_prop="sys.vivo.bt_log_trigger_err_desc"
bt_trigger_detail_desc_prop="sys.vivo.bt_log_trigger_detail_desc";
bt_trigger_report_db="persist.bluetooth.report.db"

function my_print {
    echo "${1}"
    log -t ${TAG} "${1}"
}

function get_logcat_and_snoop_file {
    # copy snoop logs from inner and sdcard path
    if [ -d "$INNER_BT_SNOOP_FILE_PATH" ]; then
        cd "$INNER_BT_SNOOP_FILE_PATH"
        for file in `ls .`; do
           cp "${file}" "${1}/${file}"
        done
    fi
    if [ -d "$SDCARD_BT_SNOOP_FILE_PATH" ]; then
        cd "$SDCARD_BT_SNOOP_FILE_PATH"
        for file in `ls .`; do
            if [ -d "${file}" ]; then
                cp ${file}/* ${1}
            else
                cp ${file} ${1}
            fi
        done
    fi

    reason=`getprop ${bt_trigger_reason_prop}`
    report_db=`getprop ${bt_trigger_report_db}`
    if [ ${reason} == "7" -o ${reason} == "17" ]; then
        #如果logcat大于20M,可能造成压缩包过大core dump无法上传,删除logcat
        size=`getFileSize "${1}/logcat.log"`
        my_print "logcat.log dump size = ${size}"
        if [ ${size} -gt 20971520 ]; then
            rm "${1}/logcat.log"
            my_print "logcat.log over size 20971520 when crash, delete"
        fi
        if [ ${report_db} == "true" ]; then
            sleep ${SLEEP_HW_ERR_DURATION}
            if [ -d "$VENDOR_DB_FILE_PATH" ]; then
                cd "$VENDOR_DB_FILE_PATH"
                newest_time="0"
                newest_file=""
                pattern_ee="db.*EE"
                pattern_ne="db.*NE"
                for file in `ls .`; do
                    if [ -d "${file}" ]; then
                        if [[ ${file} == $pattern_ee ]] || [[ ${file} == $pattern_ne ]]; then
                            modify_time=`stat -c %Y $file`
                            my_print "modify_time = ${modify_time}"
                            if [[ ${modify_time} > ${newest_time} ]]; then
                                newest_time=`date +%s -r "${file}"`;
                                newest_file=${file}
                                my_print "newest_time = ${newest_time} newest_file = ${newest_file}"
                            fi
                        fi
                    fi
                done
                if [ ${newest_file} != "" ]; then 
                    cp ${newest_file}/* ${1}
                fi
            fi
	fi
	setprop ${bt_trigger_report_db} false
    fi
    my_print `ls ${1}`
}

function getFileSize {
    result=`wc -c "${1}"`
    size=0
    for var in ${result[@]}
    do
        #读到第一个就是大小，直接返回即可
        if [ ${size} == 0 ]; then
            size=${var}
        fi
        #此处不可用return 因为return只能表示0-255
        #return ${var}
    done
    echo ${size}
}

function cl_bt_logs {
    # main starts here
    if [ ! -d "$MODULE_LOCATION" ]; then
        mkdir $MODULE_LOCATION -m 777
    fi
    if [ ! -d "$BASE_DIR" ]; then
        mkdir $BASE_DIR -m 777
    fi
    cd $BASE_DIR
    # clear to get place for the coming log
    rm *
    my_print "dumpsys start ${1}"
    dumpsys bluetooth_manager > "dump_bluetooth.txt";
    # get logcat log
    logcat -d -b main -b crash -t 100000 > "logcat.log"
    #dmesg > "kernel.log"
    reason=`getprop ${bt_trigger_reason_prop}`
    if [ ${reason} == "99" ]; then
        SLEEP_DURATION=5
    fi
    # sleep several seconds to make things ready
    my_print "sleep ${SLEEP_DURATION} seconds to make things ready"
    sleep ${SLEEP_DURATION}
    get_logcat_and_snoop_file $BASE_DIR
    tar_file="$BASE_DIR$POST_FIX"
    rm "$tar_file"
    my_print "current path ls "`ls .`
    my_print "target compress file is $tar_file"
    tar -czf "$tar_file" $BASE_DIR*
    if [ $? -eq 0 ]; then
        # Remove unzipped log files
        my_print `ls .`
    else
        my_print "Failed to tar and zip log files"
        rm "$tar_file"
        exit -1
    fi
    my_print `ls $BASE_DIR`
    # Rename log file as cloud diag required:
    # extype_subtype_filecontenthash@TIME.info
    # split file name and get the first token as trigger reason
    my_print "Last trigger reason is ${reason}"
    err_desc=`getprop ${bt_trigger_err_desc_prop}`
    my_print "Last trigger reason err_desc is ${err_desc}"
    detail_desc=`getprop ${bt_trigger_detail_desc_prop}`
    my_print "Last trigger reason detail_desc is ${detail_desc}"
    hash_addr=`getprop ${bt_trigger_hash_addr}`
    my_print "Last trigger hashaddr is ${hash_addr}"
    # Start to get the file name as cloud diag required:
    # extype_subtype_filecontenthash@TIME.info
    os_version=`getprop ro.build.version.bbk`
    timestamp=`date +%s%3N`
    imei=`getprop persist.sys.vtouch.imei`
    bdaddr=`getprop persist.vendor.service.bdroid.bdaddr`

    my_print "use reason err_desc and os_version to generate hash"
    hash=`echo "${reason}_${err_desc}_${detail_desc}_${os_version}" | md5sum -b`

    full_name="${reason}_${err_desc}_${hash}@${timestamp}.info"
    my_print "full name: ${full_name}"
    mv "$tar_file" "$full_name"
    if [ $? -eq 0 ]; then
        my_print "Formated log files: ${full_name}"
    fi

    # TODO: move to cloud and notify
    # Always make sure dest dir exists
    if [ ! -d "$MODULE_LOCATION" ]; then
        mkdir $MODULE_LOCATION -m 777
    fi
    if [ ${reason} == "99" ]; then
        DEST_LOCATION="/data/logData/modules/5200/bt/"
    fi
    if [ ! -d "$DEST_LOCATION" ]; then
        mkdir $DEST_LOCATION -m 777
    fi

    # 先清除路径原内容，再移动
    rm $DEST_LOCATION/*
    my_print "clear ${DEST_LOCATION} result is "`ls $DEST_LOCATION`
    mv $full_name $DEST_LOCATION
    my_print "after mv, go to ${DEST_LOCATION} to see "`ls $DEST_LOCATION`
    if [ $? != 0 ]; then
        my_print "Failed to move logs to cloud diag modules"
        rm $full_name
        exit -1
    fi
    full_name=$DEST_LOCATION$full_name

    chmod 777 $full_name
    if [ $? != 0 ]; then
        my_print "Failed to make log files accessible"
        exit -1
    fi

    #Notify cloud app to upload logs
    os_version=`getprop ro.build.version.bbk`
    #cur_date=`date "+%Y-%m-%d %H:%M:%S"`
    cur_date=`date +%s%N`
    #my_print $os_version
    #my_print $cur_date
    #my_print $full_name
    # 过大，大于10M则删除
    size=`getFileSize "$full_name"`
    my_print "$full_name size ${size}"
    if [ ${reason} != "7" ] && [ ${reason} != "17" ]; then
        if [ ${size} -gt 10485760 ]; then
            rm "$full_name"
            my_print "$full_name over size 10485760, delete, result is `ls $full_name`"
        fi
    else
        if [ ${size} -gt 31457280 ]; then #30M 31457280
            rm "$full_name"
            my_print "hci_err $full_name over size 31457280, delete, result is `ls $full_name`"
        fi    
    fi
    if [ ${reason} == "99" ]; then
        am broadcast -a "com.android.bluetooth.EASYSHARE_CL_DONE"
        exit -1
    fi
    my_print "dest file is "`ls $full_name`
    my_print "data {\"moduleid\":\"4000\",\"eventId\":\"00070|012\",\"dt\":{\"exptype\":${reason},\"osysversion\":\"${os_version}\",\"otime\":\"${cur_date}\"},\"fullhash\":\"${hash}\",\"logpath\":\"${full_name}\"}"
    am broadcast -a "com.vivo.intent.action.CLOUD_DIAGNOSIS" --ei "attr" 1 --ei "module" 4000 --es "data" "{\"moduleid\":\"4000\",\"eventId\":\"00070|012\",\"dt\":{\"exptype\":${reason},\"err_desc\":\"${err_desc}\",\"detail_desc\":\"${detail_desc}\",\"osysversion\":\"${os_version}\",\"otime\":\"${cur_date}\"},\"fullhash\":\"${hash}\",\"logpath\":\"${full_name}\"}" com.bbk.iqoo.logsystem
    if [ $? -eq 0 ]; then
        my_print "Send broadcast to cloud diag successfully!!"
    fi
}

my_print "Begin cl bt logs"
cl_bt_logs
