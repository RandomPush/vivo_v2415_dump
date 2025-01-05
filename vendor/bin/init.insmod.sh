#!/vendor/bin/sh

########################################################
### init.insmod.cfg format:                          ###
### -----------------------------------------------  ###
### [insmod|setprop|enable/moprobe] [path|prop name] ###
### ...                                              ###
########################################################

SYSTEM_DIR="/system_dlkm/lib/modules"
SYSTEM_GKI_DIR="/system_dlkm/lib/modules/6.6-gki"
VENDOR_DIR="/vendor/lib/modules"
VENDOR_GKI_DIR="/vendor/lib/modules/6.6-gki"

POSSIBLE_DIRS="${SYSTEM_DIR} ${SYSTEM_GKI_DIR} ${VENDOR_DIR} ${VENDOR_GKI_DIR} "

if [ $# -eq 1 ]; then
  cfg_file=$1
else
  exit 1
fi

if [ -f $cfg_file ]; then
  while IFS="|" read -r action arg
  do
    case $action in
      "insmod") insmod $arg ;;
      "setprop")
        times=1
        setprop $arg 1
        while [ "$?" -ne 0 ]
        do
          if [ $times -gt 128 ]; then
            break
          fi
          let times++
          setprop $arg 1
        done ;;
      "enable") echo 1 > $arg ;;
      "modprobe")
        insmod_arg=${arg}
        for dir in ${POSSIBLE_DIRS}
        do
          case ${insmod_arg} in
            "-b *" | "-b")
              arg="-b $(cat ${dir}/modules.load)" ;;
            "*" | "")
              arg="$(cat ${dir}/modules.load)" ;;
          esac

          first_module=$(echo ${arg} | cut -d " " -f1)

          if ! modprobe -b -s -d ${dir} -a ${first_module} > /dev/null ; then
                continue
          fi

          modprobe -a -d ${dir} $arg

          if [ "${dir}" = "${VENDOR_GKI_DIR}" ]; then
                setprop vendor.gki_ko 1
          fi
        done
    esac
  done < $cfg_file
else
  exit 2
fi

