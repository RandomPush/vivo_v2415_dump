#!/system/bin/sh

#### ORDER or RANDOM
RANDOM_STRESS=1

#### wait latency for each DVFS finish (0.1=100ms, 0.001=1ms)
T_DVFS_INTERVAL=0.02

# 用第一个参数作为超时时间（秒）
TIMEOUT=$1

# 开始的时间（以秒为单位）
start_time=$(date +%s)

#/******* Fixed MMDVFS  vcore low requirement **********/
echo 0 5 > /sys/module/mtk_mmdvfs_debug/parameters/force_step
#/******* Fixed UFS  vcore low requirement **********/
echo 3 > /sys/devices/platform/soc/16810000.ufshci/clkscale/clkscale_control


while [ 1 ]
do
	sleep $T_DVFS_INTERVAL

	fix_opp=$(($RANDOM%87)) # OPP0~OPP86 for mt6991
	fix_opp=$(($fix_opp))

##	#need vcore >= 0.60v for 120HZ mmclk
##	if [ $fix_opp -eq 29 -o $fix_opp -eq 24 -o $fix_opp -eq 19 ]; then
##		continue
##	fi

	# 当前时间（以秒为单位）
	current_time=$(date +%s)

	# 若当前时间与开始时间的差值大于或等于设定的超时时间，则退出循环
	if [ $(($current_time - $start_time)) -ge $TIMEOUT ]; then
		break
	fi

	echo $fix_opp > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp

	echo "fix_opp = $fix_opp"

	cat /sys/kernel/helio-dvfsrc/dvfsrc_dump | grep -e uv -e Mbps

done

echo -1 > /sys/module/mtk_mmdvfs/parameters/force_step
echo 255 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp
