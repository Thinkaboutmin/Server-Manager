# This should be changed if any modification is done
# Therefore, it will update the files in the remote server
MAIN_VERSION="0.1"

if [ -d "/usr/local/Scada_Files"]
then
	if [ "$MAIN_VERSION" != "$(cat /usr/local/Scada_Files/program_version)" ]
	then
		echo "||1||"
		exit 1
	else
		echo "||0||"
	fi
else
	echo "||1||"
	exit 1
fi

