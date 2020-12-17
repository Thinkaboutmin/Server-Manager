COMMAND="$1"
EX_1="$2"
EX_2="$3"
EX_3="$4"
EX_4="$5"
EX_5="$6"
EX_6="$7"

DIRECTORY="$(dirname "$0")"
DIRECTORY="$DIRECTORY/../"

source "${DIRECTORY}User_Management/user_management.sh"
source "${DIRECTORY}Miscelanous/miscs.sh"

# Reduce workload
function pp {
	echo "||$1||"
}

function ifel {
	if (($1))
	then
		pp "$2"
		exit 1
	else
		pp "$3"
		exit 0
	fi
}

case "$COMMAND" in
	"add_user")
		add_user "$EX_1" "$EX_2" "$EX_3" "$EX_4"
		ifel $? "$ADD_USER_ERROR"
		;;
	"remove_user")
		remove_user "$EX_1"
		ifel $? "$REMOVE_USER_ERROR"
		;;
	"show_user")
		show_user "$EX_1" "$EX_2"
		ifel $? "$SHOW_USER_ERROR" "$SHOW_USER_VAL"
		;;
	"modify_user")
		modify_user "$EX_1" "$EX_2" "$EX_3" "$EX_4"
		ifel $? "$MODIFY_USER_ERROR"
		;;
	"pick_user_info")
		pick_user_info "$EX_1"

		USER_INFO=""
		for TMP_USER_INFO in ${!PICK_USER_INFO_VAL[*]}
		do
			if [ -z "$USER_INFO" ]
			then
				USER_INFO="${TMP_USER_INFO}:${PICK_USER_INFO_VAL["$TMP_USER_INFO"]}"
			else
				USER_INFO="${USER_INFO}\n${TMP_USER_INFO}:${PICK_USER_INFO_VAL["$TMP_USER_INFO"]}"
			fi
		done
			
		ifel $? "$PICK_USER_INFO_ERROR" "$USER_INFO"
		;;
	"folders_and_files")
		folders_and_files "$EX1"
		ifel $? "$FOLDERS_AND_FILES_ERROR"
		;;
	*)
		ifel 1 "Unknow option! $COMMAND"
esac

