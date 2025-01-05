# function : remove unnecessary tuninglog w/o dump

cd ..

path="/data/vendor/camera_dump/"
file_pattern="*_preview*_TuningLog*.txt"

for p in $(find $path -name $file_pattern); do
	base=$(basename "$p")
	folder="UKey${base%*_*_*_preview*_TuningLog*.txt}"
	if [ ! -d "${path}/${folder}" ]; then
		# Take action if $DIR exists. #
		echo "Folder : ${path}/${folder} isn't exist..."
		rm -rf $p
	fi
done

cd $path