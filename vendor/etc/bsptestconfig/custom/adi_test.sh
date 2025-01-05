#!/bin/sh

echo "please input running times(10000 takes 10 minutes):"
read times
current_time=$(date "+%Y-%m-%d %H:%M:%S")
echo "Script is starting at: $current_time"

VAL_NUM=6
index=0
count=1
err_times=0
# board_ary["Project name"]="pmic_id_offset"="pmic_id"="test_reg_offset"
board_ary=(
	["SC9863A"]="0xc04"="0x2721"="0xee0"
	["UMS312"]="0x1804"="0x2730"="0x1bb4"
	["UMS512"]="0x1804"="0x2730"="0x1bb4"
	["UMS9230"]="0x1804"="0x2730"="0x1bb4"
)
val_pattern=("0" "5555" "5a5a" "a5a5" "aaaa" "ffff")

ADI_PATH=/sys/class/spi_master/spi4/spi4.0
PMIC_SYSCON_PATH=/sys/bus/platform/drivers/sprd-pmic-glb/sprd,sc27xx-syscon

hw_info=`cat /vendor/build.prop | grep -i "ro.board.platform"`
prj_name=`echo $hw_info | awk -F '\\=' '{printf $2}'`

printf "current platform: %s\n" "$prj_name"
prj_name_big=`echo "$prj_name" | tr '[a-z]' '[A-Z]'`

for index in ${!board_ary[*]};do
	if [[ ${board_ary[$index]} == *$prj_name_big* ]];then
		break
	fi
done

test_reg_offset=`echo ${board_ary[$index]} | awk -F '\\=' '{printf $4}'`
printf "test_reg_offset: %s\n" "$test_reg_offset"

while [ $count -le $times ]
do
	val_count=$((count%VAL_NUM))
	set_value=${val_pattern[$val_count]}
	echo $test_reg_offset >$PMIC_SYSCON_PATH/pmic_reg
	echo $set_value >$PMIC_SYSCON_PATH/pmic_value
	ret_test_res=`cat $PMIC_SYSCON_PATH/pmic_value`
	if [ $ret_test_res != $set_value ];then
		printf "fail! write value: 0x%s != read value: 0x%s\n" "$set_value" "$ret_test_res"
		err_times=$((err_times+1))
	fi
	count=$((count+1))
done

mkdir -p /data/vivo-common/BSPTest/test_file/local_custom_test
touch /data/vivo-common/BSPTest/test_file/local_custom_test/adi_test_result
if [ $err_times -gt 0 ];then
	printf "adi test fail!\n"
	echo "fail" > /data/vivo-common/BSPTest/test_file/local_custom_test/adi_test_result
else
	printf "adi test pass!\n"
	echo "pass" > /data/vivo-common/BSPTest/test_file/local_custom_test/adi_test_result
fi
current_time=$(date "+%Y-%m-%d %H:%M:%S")
echo "Script is ending at: $current_time"
