#! /bin/bash

# A few tools that will be used in other places
# Those tools are check file, system tools and etc...

if [ -z "$DIRECTORY" ]
then
	echo "The DIRECTORY variable is not defined!"
	exit 1
fi

function check_file_existency {
	# Check if a file or folder is actually there and return true
	# It have two types of, well, types.
	# FILE: Will check for the files passed as argument
	# FOLDER: Will check for the folders passed as argument

	local TYPES=("FILE" "DIRECTORY")
	
	local OPTION=$1
	
	local TYPE
	declare -i CHECKAGE=0
	for TYPE in ${TYPES[*]}
	do
		if [ $OPTION = $TYPES ]
		then
			CHECKAGE=1
			break
		fi
	done

	if ! ((CHECKAGE))
	then
		CHECK_FILE_EXISTENCY_ERROR="The option $OPTION is not availabled in ${TYPES[*]}"
		return 1
	else
		shift
	fi

	if [ $OPTION = ${TYPE[0]} ]
	then
		local FILE
		for FILE in $@
		do
			if ! [ -f "$FILE" ]
			then
				CHECK_FILE_EXISTENCY_ERROR="The file $FILE doesn't exist!"
				return 1
			fi
		done
	elif [ $OPTION = ${TYPE[1]} ]
	then
		local FOLDER
		for FOLDER in $@
		do
			if ! [ -d "$FOLDER" ]
			then
				CHECK_FILE_EXISTENCY_ERROR="The folder $FOLDER doesn't exist!"
				return 1
			fi
		done
	else
		CHECK_FILE_EXISTENCY_ERROR="Something went really wrong..."
	fi

	return 0
}

function is_it_uppercase {
	local STRING
	for STRING in $@
	do
		if [[ $STRING =~ [A-Z] ]]
		then
			return 0
		fi
	done

	return 1
}

function requirements {
	if ! hash dialog > /dev/null 2>&1
	then
		REQUIREMENTS_ERROR="There's no dialog available!"
		return 1
	fi

	if ! check_file_existency "FILE" "/etc/passwd"
	then
		REQUIREMENTS_ERROR="There's no passwd file!"
		return 1
	fi

	if ! check_file_existency "FILE" "/etc/group"
	then
		REQUIREMENTS_ERROR="There's no group file!"
		return 1
	fi

	return 0
}

function log_to_file {
	local MESSAGE="$1"
	mkdir "$DIRECTORY/Logs" > /dev/null 2>&1

	local FOLDER_TO_LOG="$DIRECTORY/Logs/$(date +%Y-%m-%d)"

	echo "$MESSAGE" >> "$FOLDER_TO_LOG"

	return 0
}

