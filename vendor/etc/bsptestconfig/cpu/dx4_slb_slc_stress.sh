#!/system/bin/sh

##### script information
script_name="DX4 SLB-SLC Stress Script"
script_version=1.0.0
script_owner=yanghui.li@mediatek.com

#### test times
ntest=1000

#### step internal sleep unit s
step_internal=0.05

##### test mode setting
test_serial_mode=0
test_random_mode=1

##### test pattern setting
test_random_cpu_slc_size_flag=1
test_random_gpu_slc_size_flag=1
test_random_user_slb_use_flag=1
test_disable_slc_flag=1
test_disable_slb_flag=1

test_all_case_count=5

###DX4 SLB user
#
#SLC User	UID
#CPU		0x0001
#GPU		0x0002
#GPU_OVL	0x0003
#VDEC_FRAME	0x0005
#VDEC_UBE	0x0006
#SMMU		0x0007
#MD			0x0008
#ADSP		0x0009
#AOV		0x000a
#IMG		0x000b
#CAM		0x000c
#MAE		0x000d
#DMR		0x000e
#OD			0x000f
#DBI		0x0010
###

SLB_USER=(CPU GPU GPU_OVL VDEC_FRAME VDEC_UBE SMMU MD ADSP AOV IMG CAM MAE DMR OD DBI)
SLB_UID=(0x0001 0x0002 0x0003 0x0005 0x0006 0x0007 0x0008 0x0009 0x000a 0x000b 0x000c 0x000d 0x000e 0x000f)

### DX4 SLC SIZE 10M
DX4_SLC_SIZE=10

#### wait latency for slc size switch (0.1=100ms, 0.001=1ms)
T_SLC_INTERVAL=0.02

### show basic script information
function show_basic_infor(){
	echo $script_name, version=$script_version, script creater=$script_owner
}

function test_random_cpu_slc_size() {
	if [ $test_random_cpu_slc_size_flag -eq 0 ]; then
		return
	fi

	test_slc_size=$(($RANDOM%$DX4_SLC_SIZE))
	test_slc_size=$(($test_slc_size+1))
	if [ $test_slc_size -eq 10 ]; then
		test_slc_size=a
	fi
	
	echo "DX4 CPU SLC random size test:${test_slc_size}"
#	echo slbc_force ${test_slc_size}0001
	echo slbc_force ${test_slc_size}0001 > /proc/slbc/dbg_slbc
	
	# sleep
	sleep $T_SLC_INTERVAL
	
	echo slbc_force 00001 > /proc/slbc/dbg_slbc
}

function test_random_gpu_slc_size() {
	if [ $test_random_gpu_slc_size_flag -eq 0 ]; then
		return
	fi

	test_slc_size=$(($RANDOM%$DX4_SLC_SIZE))
	test_slc_size=$(($test_slc_size+1))
	if [ $test_slc_size -eq 10 ]; then
		test_slc_size=a
	fi
	
	echo "DX4 GPU SLC random size test:${test_slc_size}"
#	echo slbc_force ${test_slc_size}0002
	echo slbc_force ${test_slc_size}0002 > /proc/slbc/dbg_slbc
	
	# sleep
	sleep $T_SLC_INTERVAL
	
	echo slbc_force 00002 > /proc/slbc/dbg_slbc
}

function test_random_user_slb_use() {
	if [ $test_random_user_slb_use_flag -eq 0 ]; then
		return
	fi

	test_index=$((${RANDOM}%${#SLB_UID[@]}))
	test_uid=${SLB_UID[$test_index]}
	test_user=${SLB_USER[$test_index]}
	
	echo "DX4 SLB random user request test"
	echo slb request with user:${test_uid}/${test_user}
	echo test_slb_request ${test_uid} > /proc/slbc/dbg_slbc
	
	# sleep
	sleep $T_SLC_INTERVAL
	
	echo test_slb_release ${test_uid} > /proc/slbc/dbg_slbc
}

function test_disable_slc() {
	if [ $test_disable_slc_flag -eq 0 ]; then
		return
	fi

	echo "DX4 SLC disable test"
	
	# disable slc
	echo slc_disable 1 > /proc/slbc/dbg_slbc
	# sleep
	sleep $T_SLC_INTERVAL
	# free run
	echo slc_disable 0 > /proc/slbc/dbg_slbc
}

function test_disable_slb() {
	if [ $test_disable_slb_flag -eq 0 ]; then
		return
	fi
	
	echo "DX4 SLB disable test"
	# disable slb
	echo slb_disable 1 > /proc/slbc/dbg_slbc
	# sleep
	sleep $T_SLC_INTERVAL
	# free run
	echo slb_disable 0 > /proc/slbc/dbg_slbc
}

function do_random_test_flow(){
	for rotate in $(seq 1 ${test_all_case_count})
	do
		select_test=$(($RANDOM%$test_all_case_count))

		if [ $select_test -eq 0 ]; then
			test_random_cpu_slc_size
		elif [ $select_test -eq 1 ]; then
			test_random_gpu_slc_size
		elif [ $select_test -eq 2 ]; then
			test_random_user_slb_use
		elif [ $select_test -eq 3 ]; then
			test_disable_slc
		elif [ $select_test -eq 4 ]; then
			test_disable_slb
		else
			echo test_all_case_count=$test_all_case_count, is not match setting, exit.
			exit 1
		fi

		sleep $step_internal

	done 
}

function do_serial_test_flow(){

	echo "DX4 SLB SLC serial test"

	test_random_cpu_slc_size_flag
	sleep $step_internal
	
	test_random_gpu_slc_size_flag
	sleep $step_internal
	
	test_random_user_slb_use
	sleep $step_internal
	
	test_disable_slc
	sleep $step_internal
	
	test_disable_slb
	sleep $step_internal
}


########## main test flow

show_basic_infor

## first start to cpu idle test scenes, to disable keyguard.
locksettings set-disabled true

for i in $(seq 1 ${ntest})
do

	echo test-loop:$i

	if [ $test_serial_mode -eq 1 ]; then
		do_serial_test_flow
	else
		do_random_test_flow
	fi
done

## clean disable keygurad setting.
locksettings set-disabled false

echo "exit DX4 SLB SLC stress test"
