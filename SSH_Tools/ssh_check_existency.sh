PATH="/usr/local/Scada_Files"
PROGRAM_VERSION="0.1"

if [ -d "$PATH" ]
then
	if [ -f "${PATH}/program_version" ]
	then
		if [ "$(cat "${PATH}/program_version")" != "$PROGRAM_VERSION" ]
		then
			echo -e "||1||\n||Different file version! Resending program||"
			exit 1
		else
			echo "||0||"
		fi
	else
		echo -e "||1||\n||No program_version file was found!"
		exit 1
	fi
else
	echo -e "||1||\n||The program directory wasn't found!||"
	exit 1
fi


