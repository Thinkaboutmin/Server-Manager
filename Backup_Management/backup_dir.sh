# A small library for backup affairs

if [ -z "$DIRECTORY" ]
then
	echo "There's no directory variable defined!"
	exit 1
fi

if ! hash rsync > /dev/null 2>&1
then
	declare -i RSYNC=1
fi

if ! hash scp > /dev/null 2>&1
then
	declare -i SCP=1
fi

if ((SCP && RSYNC))
then
	echo "There's no scp or rsync binary available on path!"
fi

function verify_path {
	local LOCAL_PATH="$1"

	if ! [ -s "$LOCAL_PATH" ]
	then
		VERIFY_PATH_ERROR="There's no path available!"
		return 1
	fi
	
	return 0
}

function backup_file {
	local BACKUP_DIR="$DIRECTORY/Servers_Backup"

	mkdir "$BACKUP_DIR" > /dev/null 2>&1

	local FROM_SERVER="$1"
	local FROM_SERVER_FOLDER="$2"

	local TO_SERVER="$3"
	local TO_SERVER_FOLDER="$4"

	echo "$FROM_SERVER $FROM_SERVER_FOLDER to $TO_SERVER $TO_SERVER_FOLDER" >> "$BACKUP_DIR/${FROM_SERVER}.bak"

	return 0
}

function folders_and_files {
	declare -ag FILES_=""
	declare -ag FOLDERS_=""
	local PATH_="$1"

	if [ -z "$PATH_" ]
	then
		FOLDERS_AND_FILES_ERROR="Nothing was passed in the first argument!"
		return 1
	fi

	if ! verify_path "$PATH_"
	then
		FOLDERS_AND_FILES_ERROR="$VERIFY_PATH_ERROR"
		unset VERIFY_PATH_ERROR
		return 1
	fi
	
	local FILE_FOLDER
	local IFS="$(printf '\n\t')"
	for FILE_FOLDER in $(ls -1 "$PATH_")
	do
		if grep "/\$" <<< "$PATH_"
		then
			FILE_FOLDER="$PATH_""$FILE_FOLDER"
		else
			FILE_FOLDER="$PATH_/""$FILE_FOLDER"
		fi

		if [ -d "$FILE_FOLDER" ]
		then
			FOLDERS_+="$FILE_FOLDER/ "
		else
			FILES_+="$FILE_FOLDER "
		fi
	done

	FOLDERS_AND_FILES_VAR="FOLDERS ${FOLDERS[*]} FILES ${FILES[*]}"

	return 0
} 

function backup_ {
	FROM_PATH=$1
	TO_PATH=$2

	if [ -z "$FROM_PATH" ]
	then
		BACKUP_ERROR="No argument was passed in the first section!"
		return 1
	elif [ -z "$TO_PATH" ]
	then
		BACKUP_ERROR="No argument was passed in the second section!"
		return 1
	fi
	
	local DEFAUlT_BACKUP_MESSAGE="Couldn't realize the backup!"

	if ((SCP))
	then
		if ! rsync "$FROM_PATH" "$TO_PATH" > /dev/null 2>&1
		then
			BACKUP_ERROR="$DEFAUlT_BACKUP_MESSAGE"
			return 1
		fi
	else
		if ! scp "$FROM_PATH" "$TO_PATH" > /dev/null 2>&1
		then
			BACKUP_ERROR="$DEFAUlT_BACKUP_MESSAGE"
			return 1
		fi
	fi

	return 0
}

