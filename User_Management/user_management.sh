#! /bin/bash

# A small library which contains functions to manage users in a system
# It's possible to change the username, shell, directory and a few other
# things with this. It's kinda basic, but it should give errors when
# badly used, therefore, easier to work with.

function does_it_exist {
	# Verify if the user exist in the system
	# and return true otherwise false
	# This creates a default variables called DOES_IT_EXIST
	# other than it ending with VAL or ERROR
	# But, as this should be used only in function from this
	# library, there shouldn't be any lingering problem.

	local NAME_USER=$1

	if [ -z "$NAME_USER" ]
	then
		DOES_IT_EXIST="No user was informed!"
		return 0
	fi

	if cut -d ":" -f 1 "/etc/passwd" | grep -oq "^$NAME_USER\$"
	then
		DOES_IT_EXIST="The user is already on the system!"
		return 0
	else
		DOES_IT_EXIST="The user doesn't exist!"
		return 1
	fi
}

function check_group_existency {
	# Check if the group passed through the arguments
	# do actually exist, thus, avoiding errors.
	# Although the function which would create the user
	# would bogus, this will make it easier to
	# identify the mistake.
	
	local GROUP_PATH="/etc/group"
	
	if [ -f "$GROUP_PATH" ]
	then
		local ALL_GROUPS=$(cat "$GROUP_PATH" | cut -f 1 -d ":")
	else
		CHECK_GROUP_EXISTENCY_ERROR="There's no group file in etc!"
		return 1
	fi

	local TO_VERIFY_GROUP
	declare -i CHECKAGE
	for TO_VERIFY_GROUP in $@
	do
		CHEKAGE=0
		local GROUP
		for GROUP in $ALL_GROUPS
		do
			if [ "$GROUP" = "$TO_VERIFY_GROUP" ]
			then
				CHECKAGE=1
				break
			fi
		done
		
		if ((! CHECKAGE ))
		then
			CHECK_GROUP_EXISTENCY_ERROR="The group $TO_VERIFY_GROUP does not exist!"
			return 1
		fi
	done

	return 0
}

function add_user {
	# Adds a user
	# First argument is the username
	# Second argument is the user folder
	# Third argument is the user group(s)
	# Fourth argument is the user shell

	local NAME_USER=$1
	local FOLDER_USER=$2
	local GROUPS_USER_TMP=$3
	local USER_TERMINAl=$4
	
	# Function from Miscelanous folder'
	if is_it_uppercase "$NAME_USER" "$GROUPS_USER_TMP"
	then
		ADD_USER_ERROR="Do not use uppercase on names and groups!"
		return 1
	fi

	if does_it_exist "$NAME_USER"
	then
		ADD_USER_ERROR="$DOES_IT_EXIST"
		unset DOES_IT_EXIST
		return 1
	fi

	unset DOES_IT_EXIST
		
	declare -i GROUPS_NUMBER=0
	
	local None
	for None in $GROUPS_USER_TMP
	do
		((++GROUPS_NUMBER))
	done

	unset None

	# Make each group into a entire line
	# TODO This opens a possibility for errors!
	# Or not...
	if ((GROUPS_NUMBER >= 1))
	then
		declare -i CONTROL=0
		local GROUP
		for GROUP in $GROUPS_USER_TMP
		do
			if ! check_group_existency "$GROUP"
			then
				ADD_USER_ERROR="$CHECK_GROUP_EXISTENCY_ERROR"
				unset CHECK_GROUP_EXISTENCY_ERROR
				return 1
			fi

			((++CONTROL))
			if ((CONTROL != GROUPS_NUMBER))
			then
				local GROUPS_USER="$GROUPS_USER$GROUP,"
			else
				local GROUPS_USER="$GROUPS_USER$GROUP"
			fi
		done
	else
		local GROUPS_USER="$GROUPS_USER_TMP"
		unset GROUPS_USER_TMP
	fi
	
	if ! [ -z "$GROUPS_USER" ]
	then
		# The first -g fixes a small issue whenever there's
		# no folder_user variable
		GROUPS_USER="-G $GROUPS_USER"
	fi

	if ! [ -z "$FOLDER_USER" ]
	then
		FOLDER_USER="-d $FOLDER_USER -m"
	fi

	if ! [ -z "$USER_TERMINAl" ]
	then
		USER_TERMINAl="-s $USER_TERMINAl"
	fi

	if ! useradd $FOLDER_USER $NAME_USER $GROUPS_USER $USER_TERMINAl > /dev/null 2>&1
	then
		ADD_USER_ERROR="Impossible to create the user!"
		return 1
	fi

	return 0
}

function remove_user {
	# Remove the user and all his files from the
	# home directory of the whose said user.

	local NAME_USER=$1

	if [ $NAME_USER ]
	then
		if does_it_exist $NAME_USER
		then
			unset DOES_IT_EXIST
			if ! userdel -r $NAME_USER > /dev/null 2>&1
			then
				REMOVE_USER_ERROR="The user couldn't be deleted!"
				return 1
			fi
		else

			REMOVE_USER_ERROR="$DOES_IT_EXIST"
			unset DOES_IT_EXIST
			return 1
		fi
	else 
		REMOVE_USER_ERROR="No user was passed!"
		return 1
	fi

	return 0
}

function show_user {
	# Creates a variable called SHOW_USER_VAL which contains related content with the option
	# chosen, such as ALL. This will only return NAMES of the users!
	# Options:
	# ALL show all users on the system, no matter if it can be logged or not
	# LOGABLE only show users which can be logged, or, that at least don't use nologin or false "shell"
	# UNLOGABLE only show users which can't be logged, same as above for search criteria

	local POSSIBLY_SHOW=("ALL" "LOGABLE" "UNLOGABLE")
	local OPTION_CHOSEN="$1"
	local PICK_USER="$2"

	case $OPTION_CHOSEN in
		"${POSSIBLY_SHOW[0]}")
			SHOW_USER_VAL=$(cat /etc/passwd | cut -d ":" -f 1)
			if ! [ -z "$PICK_USER" ]
			then
				SHOW_USER_VAL=$(grep "$PICK_USER" <<< $SHOW_USER_VAL)
			fi
			;;

		"${POSSIBLY_SHOW[1]}")
			SHOW_USER_VAL=$(cat /etc/passwd | grep -v "/*/nologin" | grep -v "/*/false" | cut -d ":" -f 1)

			if ! [ -z "$PICK_USER" ]
			then
				SHOW_USER_VAL=$(grep "$PICK_USER" <<< $SHOW_USER_VAL)
			fi
			;;

		"${POSSIBLY_SHOW[2]}")
			SHOW_USER_VAL=$(cat /etc/passwd | grep -e "/*/nologin" -e "/*/false" | cut -d ":" -f 1)

			if ! [ -z "$PICK_USER" ]
			then
				SHOW_USER_VAL=$(grep "$PICK_USER" <<< $SHOW_USER_VAL)
			fi
			;;
		*)
			SHOW_USER_ERROR="There's no such option $OPTION_CHOSEN available, only ${POSSIBLY_SHOW[*]}"
			return 1
			;;
	esac

	if [ -z "$SHOW_USER_VAL" ]
	then
		# TODO Probably unfeaseable
		SHOW_USER_ERROR="There seems to be nothing in the file passwd using the option $OPTION_CHOSEN..."
		return 1
	fi

	return 0
}

function pick_user_info {
	# Pick all the user info and throw it into a
	# variable called PICK_USER_INFO_VAL
	# This variables contains an array
	# with string index, such as NAME
	# SHELL and the whereabouts of the passwd file

	local USER=$1

	if ! does_it_exist "$USER"
	then
		PICK_USER_INFO_ERROR="$DOES_IT_EXIST"
		unset DOES_IT_EXIST
		return 1
	fi

	unset DOES_IT_EXIST
	
	# Adds : as the last character, so that the shell could be picked
	local USER_GENERAL_INFO=$(cat /etc/passwd | grep "$USER")":"
	
	# Iterate through every single character because
	# sometimes there's null value which constains only ::
	# and this is troublesome to bypass with bash built-ins
	# therefore, it needs to do some hackish way for it
	# which is this iteration type. At least, IMO.
	
	declare -i TIMES=0
	declare -i SECTION=0
	declare -A -g PICK_USER_INFO_VAL
	local SECTIONS=("NAME" "PASSWORD" "UID" "GID" "GECOS" "HOME_DIR" "SHELL" "GROUPS")
	local WORD_GENERATED=false
	local WORD=""
	for ((i = 0; i < ${#USER_GENERAL_INFO}; ++i))
	do
		if [ "${USER_GENERAL_INFO:$i:1}" = ":" ]
		then
			((++TIMES))

			if ((TIMES == 1)) && ! [ $WORD_GENERATED ]
			then
				WORD="UNDEFINED"
				PICK_USER_INFO_VAL["${SECTIONS[$SECTION]}"]="$WORD"
				WORD=""
				((++SECTION))
				TIMES=0
				continue
			fi
			
			if [ $WORD_GENERATED ]
			then
				PICK_USER_INFO_VAL["${SECTIONS[$SECTION]}"]="$WORD"
				WORD=""
				((++SECTION))
				WORD_GENERATED=false
				TIMES=0
			fi
		else
			WORD="$WORD""${USER_GENERAL_INFO:i:1}"
			WORD_GENERATED=true
		fi
	done
	
	PICK_USER_INFO_VAL[${SECTIONS[7]}]="$(groups $USER | cut -d ":" -f 2 | sed "s/ //1")"
	return 0
}

function modify_user {
	# Modify a user
	# First argument is the username
	# Second argument is the new username
	# Third argument is the user folder
	# Fourth is the user groups
	# Fifth is the user shell
	
	local NAME_USER=$1

	if ! does_it_exist $NAME_USER
	then
		MODIFY_USER_ERROR="$DOES_IT_EXIST"
		unset DOES_IT_EXIST
		return 1
	else
		# TODO handle the user change better when no other parameter
		# is passed as it should
		local USER_SHELL=$5
		if ! [ -z "$USER_SHELL" ]
		then
			echo "WOW"
			if ! chsh $NAME_USER "-s" $USER_SHELL > /dev/null 2>&1
			then
				MODIFY_USER_ERROR="Couldn't change the shell to $USER_SHELL"
			fi
		fi
	fi

	unset DOES_IT_EXIST

	local CHANGE_USER_NAME=$2
	if ! [ -z "$CHANGE_USER_NAME" ]
	then
		if [ $NAME_USER = $CHANGE_USER_NAME ]
		then
			CHANGE_USER_NAME=""
		else
			CHANGE_USER_NAME="-l $CHANGE_USER_NAME"
		fi
	fi
	
	# TODO On dialog show the default USER_FOLDER and user groups

	local FOLDER_USER=$3  # $(grep "$NAME_USER" /etc/passwd | cut -d ":" -f 6) -e FOLDER_USER
	local GROUPS_USER_TMP=$4  # $(groups $NAME_USER) -e GROUPS_USER_TMP
	local USER_SHELL=$5
		
	declare -i GROUPS_NUMBER=0
	
	local None
	for None in $GROUPS_USER_TMP
	do
		((++GROUPS_NUMBER))
	done
	unset None
	
	if ((GROUPS_NUMBER >= 1))
	then
		declare -i CONTROL=0
		local GROUP
		for GROUP in $GROUPS_USER_TMP
		do
			if ! check_group_existency "$GROUP"
			then
				MODIFY_USER_ERROR="$CHECK_GROUP_EXISTENCY_ERROR"
				unset CHECK_GROUP_EXISTENCY_ERROR
				return 1
			fi

			((++CONTROL))
			if ((CONTROL != GROUPS_NUMBER))
			then
				local GROUPS_USER="$GROUPS_USER$GROUP,"
			else
				local GROUPS_USER="$GROUPS_USER$GROUP"
			fi
		done
	else
		local GROUPS_USER="$GROUPS_USER_TMP"
		unset GROUPS_USER_TMP
	fi

	if ! [ -z "$GROUPS_USER" ]
	then
		GROUPS_USER="-G $GROUPS_USER"
	fi

	if ! [ -z "$FOLDER_USER" ]
	then
		FOLDER_USER="-d $FOLDER_USER -m"
	fi

	if ! usermod $CHANGE_USER_NAME $GROUPS_USER $FOLDER_USER $NAME_USER > /dev/null 2>&1
	then
		MODIFY_USER_ERROR="Impossible to modify the user!"
		return 1
	fi

	return 0
}

