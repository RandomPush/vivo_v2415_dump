#!/vendor/bin/sh

# used for judging the provisioned state of RPMB

platform=`getprop ro.vivo.product.solution`
echo $platform

if [ "$platform" == "QCOM" ]
then
    file_content=`cat /proc/sec_rpmb_prov`
    echo $file_content
    if [ -n "$file_content" ] && [ "$file_content" != "0x00000000" ]
    then
        echo "rpmb has been provisioned"
        setprop ro.vendor.seed.rpmb_provisioned 1
    else
        echo "rpmb has not been provisioned"
        setprop ro.vendor.seed.rpmb_provisioned 0
    fi

elif [ "$platform" == "MTK" ]
then
    res_tlcrpmb=`/vendor/bin/tlcrpmb_gp getflag`
    res_mtk=$(echo $res_tlcrpmb | grep "result=1")
    if [[ "$res_mtk" != "" ]]
    then
        echo "rpmb has been provisioned"
        setprop ro.vendor.seed.rpmb_provisioned 1
    else
        echo "rpmb has not been provisioned"
        setprop ro.vendor.seed.rpmb_provisioned 0
    fi

elif [ "$platform" == "SAMSUNG" ]
then
    res_bRPMB=`/vendor/app/bRPMB-CMD -c`
    res_samsung=$(echo $res_bRPMB | grep "RPMB has been provisioned")
    if [[ "$res_samsung" != "" ]]
    then
        echo "rpmb has been provisioned"
        setprop ro.vendor.seed.rpmb_provisioned 1
    else
        echo "rpmb has not been provisioned"
        setprop ro.vendor.seed.rpmb_provisioned 0
    fi

else
    echo "the platform is not supported!"
fi
