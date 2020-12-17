if [ -z "$DIRECTORY" ]
then
	echo "There's no DIRECTORY variable defined!"
	exit 1
elif [ -z "$TMP_INFO" ]
then
	echo "There's no TMP_INFO variable defined!"
	exit 1
fi

function send_com {
	# Sends a command from ssh to the Server_Side/commands.sh
	# there, it will basically do the command and return the value

	declare -i PUBLIC_KEY=$1
	local USERNAME="$2"
	local IP="$3"
	declare -i PORT=$4
	local PASSWORD="$5"
	local COMMAND="$6"

	if ((PUBLIC_KEY))
	then
		coproc ssh -p $PORT $USERNAME@$IP -q "bash /usr/local/Scada_Files/Server_Side/commands.sh $COMMAND; catch=\$?;echo \"EXIT_STATUS:\$catch\"" > "$TMP_INFO" 2>&1
	else
		coproc sshpass -p "$PASSWORD" ssh -p $PORT $USERNAME@$IP -q "bash /usr/local/Scada_Files/Server_Side/commands.sh $COMMAND; catch=\$?;echo \"EXIT_STATUS:\$catch\"" > "$TMP_INFO" 2>&1
	fi

	declare -i CATCH_PID=$COPROC_PID
	declare -i TIME=0
	declare -i LIMIT=15

	while [ -z "$(cat "$TMP_INFO")" ]
	do
		sleep 1
		((++TIME))
		if ((TIME == LIMIT))
		then
			kill "$CATCH_PID" > /dev/null 2>&1
			SEND_COM_ERROR="Impossible to connect, maybe it needs a password?"
			return 1
		fi
	done

	wait $CATCH_PID

	declare -i EXIT_STATUS="$(grep "EXIT_STATUS:" "$TMP_INFO" | sed "s/EXIT_STATUS://g")"
	sed -i '$ d' "$TMP_INFO"

	if ((EXIT_STATUS))
	then
		SEND_COM_ERROR="$(cat "TMP_INFO")"
		return 1
	fi

	SEND_COM_VAL=$(cat "$TMP_INFO" | sed "s/||//g")

	return 0
}

function check_com {
	# Checks the program_version file or if it's even exist
	# then, sends the entire program to corelate to it's source

	declare -i PUBLIC_KEY=$1
	local USERNAME="$2"
	local IP="$3"
	declare -i PORT=$4
	local PASSWORD="$5"

	if ((PUBLIC_KEY))
	then
		coproc ssh -p $PORT $USERNAME@$IP -q 'bash -s' < "$DIRECTORY/SSH_Tools/ssh_check_existency.sh" > "$TMP_INFO" 2>&1
	else
		coproc sshpass -p "$PASSWORD" ssh -p $PORT $USERNAME@$IP -q 'bash -s' < "$DIRECTORY/SSH_Tools/ssh_check_existency.sh" > "$TMP_INFO" 2>&1
	fi

	declare -i CATCH_PID=$COPROC_PID
	declare -i TIME=0
	declare -i LIMIT=15

	while [ -z "$(grep "||.*||" "$TMP_INFO" | sed "s/||//g")" ]
	do
		sleep 1
		((++TIME))
		if ((TIME == LIMIT))
		then
			kill "$CATCH_PID" > /dev/null 2>&1
			CHECK_COM_ERROR="Impossible to connect, server down or incorrect password or configuration"
			return 1
		fi
	done

	local RESULT="$(grep "||.*||" "$TMP_INFO" | head -1 | sed "s/||//g")"

	((! RESULT)) && CHECK_COM_ERROR="$(grep "||.*||" "$TMP_INFO" | head -2 | sed "s/||//g")" && return 1
	
	# TODO rsync as the first and foremost option
	if ((PUBLIC_KEY))
	then
		scp -r "$DIRECTORY/../Scada_Files" "$USERNAME@$IP:/usr/local"
	else
		sshpass -p "$PASSWORD" scp -r "$DIRECTORY/../Scada_Files" "$USERNAME@$IP:/usr/local"
	fi

	return 0
}

#send_com "0" "root" "192.168.1.105" "22" "comschnauzer" "show_user \"ALL\""
