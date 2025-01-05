#!/system/bin/sh

echo 100 1 3 > /proc/mtk_lpm/cpuidle/state/latency
echo 100 1 3 > /proc/mtk_lpm/cpuidle/state/residency
echo 1000 > /proc/mtk_lpm/cpuidle/control/stress_time
echo 1 > /proc/mtk_lpm/cpuidle/control/stress
echo 1 > /proc/mtk_lpm/cpuidle/info
