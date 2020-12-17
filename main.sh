#! /bin/bash

# What a complicated project...

# Some global variables, easier to modify and mantain

PROGRAM_TITLE="Server Management"
DIRECTORY=$(dirname "$0")
FILE_SERVER="$DIRECTORY/Servers"
TMP_INFO="$HOME/info.tmp"

# A few obligatory libraries, so that this program works nicely'

if ! source "$DIRECTORY/User_Management/user_management.sh" > /dev/null 2>&1
then
	echo "There's no user_management library!"
	exit 1
elif ! source "$DIRECTORY/Miscelanous/miscs.sh" > /dev/null 2>&1
then
	echo "There's no miscs library!"
	exit 1
elif ! source "$DIRECTORY/Ip_Management/ip_handler.sh" > /dev/null 2>&1
then
	echo "There's no ip handler library!"
	exit 1
elif ! source "$DIRECTORY/Lexer_Server/lexer.sh" > /dev/null 2>&1
then
	echo "There's no lexer library!"
	exit 1
elif ! source "$DIRECTORY/Ip_Management/ping_tester.sh" > /dev/null 2>&1
then
	echo "There's no ping tester library!"
	exit 1
elif ! source "$DIRECTORY/SSH_Tools/ssh_tools.sh" > /dev/null 2>&1
then
	echo "There's no ssh tools library!"
	exit 1
elif ! source "$DIRECTORY/Backup_Management/backup_dir.sh" > /dev/null 2&1
then
	echo "There's no backup management library!"
	exit 1
fi

declare -i INFO=0
declare -i ERROR=1
# Start of functions definitions

function remote_or_local_command {
	if [ "$1" = "LOCAL" ]
	then
		shift
		$1
	else
		shift
		COMMAND="$1"
		shift
		$COMMAND $@
	fi
	
	return 0
}

function server_menu {
	# Creates a dynamic menu from the servers file
	# showing if it's up and down by taking the results
	# from ping, which is testes once
	# Btw, do not take the value from the test
	# seriously, it's just a extra

	add_server "LOCAL" "127.0.0.1"
	unset ADD_SERVER_ERROR
	
	while true
	do
		list_all_servers
		unset SERVER_INFO

		declare -A SERVER_INFO
		declare -i COUNT=0
		declare -ag DOWN_LIST_SERVERS
		local SERVER_TMP

		dialog 	--title "$PROGRAM_TITLE" \
			--infobox "Please wait, checking the servers..." 0 0 \
			--output-fd 1

		
		for SERVER_TMP in $LIST_ALL_SERVERS_VAL
		do
			if ((COUNT == 0))
			then
				local SERVER_IN_USE="$SERVER_TMP"
			
				SERVER_INFO["$SERVER_TMP"]=""
				((++COUNT))
			else
				if test_IP "$SERVER_TMP"
				then
					SERVER_INFO["$SERVER_IN_USE"]="${SERVER_TMP}:\Z2UP"
				else
					SERVER_INFO["$SERVER_IN_USE"]="${SERVER_TMP}:\Z1DOWN"
					DOWN_LIST_SERVERS+=("$SERVER_IN_USE")
				fi
				((--COUNT))
			fi
		done

		dialog 	--clear \
			--title "$PROGRAM_TITLE" \
			--extra-button --extra-label "Add Server" \
			--help-button --help-label "Delete Server" \
			--colors \
			--ok-label "Select" \
			--cancel-label "Exit" \
			--menu "Servers" 0 0 0 \
			$(for SERVER in ${!SERVER_INFO[*]};do echo "$SERVER"; echo "${SERVER_INFO["$SERVER"]}";done) \
			--output-fd 1 \
			> "$TMP_INFO"
		
		declare -i RET_VAL=$?

		case $RET_VAL in
			3)
				add_server_gui

				continue
				;;
			2)
				local VALUE=$(cut -d " " -f 2 "$TMP_INFO")

				if [ "$VALUE" = "LOCAL" ]
				then
					error_message "It's not possible to delete the local server!"
				else
					remove_server_gui "$VALUE"
				fi

				continue
				;;
			1)
				return 1
				;;
			0)
				SERVER_NAME="$(cat "$TMP_INFO")"
				SERVER_IP="$(cut -d ":" -f 1 <<< ${SERVER_INFO["$SERVER_NAME"]})"
				
				return 0
				;;
			*)
				error_message "HOW?!"
				return 1
		esac

	done

	return 0
}

function menu_server_less {
	# Show all servers, but without ping and a few
	# other tools from the main menu_server function
	# This is used to show a server menu for backup section

	list_all_servers
	unset SERVER_INFO

	declare -A SERVER_INFO
	declare -i COUNT=0
	local SERVER_TMP
	
	for SERVER_TMP in $LIST_ALL_SERVERS_VAL
	do
		if ((COUNT == 0))
		then
			local SERVER_IN_USE="$SERVER_TMP"
		
			SERVER_INFO["$SERVER_TMP"]=""
			((++COUNT))
		else
			SERVER_INFO["$SERVER_IN_USE"]="$SERVER_TMP"
			((--COUNT))
		fi
	done

	dialog 	--clear \
		--title "$PROGRAM_TITLE" \
		--ok-label "SELECT" \
		--menu "Servers" 0 0 0 \
		$(for SERVER in ${!SERVER_INFO[*]};do echo "$SERVER"; echo "${SERVER_INFO["$SERVER"]}";done) \
		--output-fd 1 \
		> "$TMP_INFO"

	SERVER_NAME="$(cat "$TMP_INFO")"
	SERVER_IP="${SERVER_INFO["$SERVER_NAME"]}"

	return 0
}

function servers_test {
	return 0
}

function cron_mark {
	declare -i FIRST_TIME
	declare -i RET_VAL

	while true
	do
		local H_M_S="$(dialog \ 
			--title "$PROGRAM_TITLE" \
			--cancel-label "Back" \
			--timebox "Cron H:M:S" 0 0 \
			--output-fd 1
		)"

		RET_VAL=$?

		if ((RET_VAL))
		then
			return 1
		fi

		while true
		do

			dialog 	--title "$PROGRAM_TITLE" \
				--yesno "Do you want to add specific year, month and day?" 0 0
			
			RET_VAL=$?

			if ((RET_VAL))
			then
				break
			fi
			
			while true
			do
				local Y_M_D="$(dialog \
					--title "$PROGRAM_TITLE" \
					--checklist "Specific Day Month or Year" 0 0 0 \
					"0" "DAY" "off" \
					"1" "MONTH" "off" \
					"2" "YEAR" "off"
				)"
				
				RET_VAL=$?
				
				if ((RET_VAL))
				then
					break
				fi

				local CONFIGURE_Y_M_D
				declare -i COUNT="0"
				for CONFIGURE_Y_M_D in $Y_M_D
				do
					case $COUNT in
						0)
							declare -i YEAR=$CONFIGURE_Y_M_D
							;;
						1)
							declare -i MONTH=$CONFIGURE_Y_M_D
							;;
						2)
							declare -i DAY=$CONFIGURE_Y_M_D
					esac

					((++COUNT))
				done

				# TODO is this important? maybe there's an online library which contain
				# a dialog cron selection :P
				if ((RET_VAL))
				then
					break
				fi
			done
			break
		done
		break
	done

	
	declare -A CRON_TIME

	CRON_TIME["HOURS"]="$(cut -d ":" -f 1 <<< $H_M_S)"
	CRON_TIME["MINUTES"]="$(cut -d ":" -f 2 <<< $H_M_S)"
	CRON_TIME["SECONDS"]="$(cut -d ":" -f 3 <<< $H_M_S)"

	return 0
}

function backup_management_gui {
	local RESULT
	declare -i RET_VAL

	while true
	do
		dialog 	--title "$PROGRAM_TITLE" \
			--menu "$SERVER_NAME Backup Management" 0 0 0 \
			"0" "Cron Them" \
			"1" "Add Backup" \
			"2" "Delete Backup(s)" \
			"3" "Backup Now" \
			--output-fd 1 \
			> "$TMP_INFO"

		RET_VAL=$?

		if ((RET_VAL))
		then
			return 1
		fi
		
		local RESULT="$(cat "$TMP_INFO")"

		case $RESULT in
			0)
				echo "WIP"
				continue
				;;
			1)
				backup_main
				continue
				;;
			2)
				echo "WIP"
				continue
				;;
			3)
				backup_selection
				continue
				;;
			*)
				error_message "How did you get here???"
				return 1
		esac
	done

	return 0
}

function backup_selection {
	local SERVER_BACKUPS="$DIRECTORY/Servers_Backup/${SERVER_NAME}.bak"

	if ! verify_path "$SERVER_BACKUPS"
	then
		error_message "$VERIFY_PATH_ERROR" "VERIFY_PATH_ERROR"
		return 1
	fi
	
	local Test=$(awk '
		BEGIN {
			counter = 0
		}

		{
			print "\"" counter "\" " "\"" $0 "\" " "\"" "off" "\" " "\\"
			++counter
		}
		' "$SERVER_BACKUPS"
		)

	for haha in $Test
	do
		error_message "$haha"
	done

	dialog 	--title "$PROGRAM_TITLE" \
		--checklist "List of backups" 0 0 0 \
		"0" "aa" "off" \
		--output-fd 1 \
		> "$TMP_INFO" 2>&1
	error_message "$(cat "$TMP_INFO")"

	declare -i RET_VAL=$?

	if ((RET_VAL))
	then
		error_message "There's no backup section!"
		return 1
	fi

	return 0
}

function backup_main {
	declare -i RET_VAL
	while true
	do
		backup_define_gui
		RET_VAL $?
		if ((RET_VAL))
		then
			return 1
		fi

		local PRIMARY_PATH="$BACKUP_VAL"
		unset BACKUP_VAL
		
		local MAIN_SERVER="$SERVER_NAME"
		local MAIN_SERVER_IP="$SERVER_IP"
		
		while true
		do
			menu_server_less

			RET_VAL=$?
			if ((RET_VAL))
			then
				continue
			fi
		done
		
		backup_define_gui
		local SECOND_PATH="$BACKUP_VAL"
		unset BACKUP_VAL

		backup_file "$MAIN_SERVER" "$PRIMARY_PATH" "$SERVER_NAME" "$SECOND_PATH"

		SERVER_NAME="$MAIN_SERVER"
		SERVER_IP="$MAIN_SERVER_IP"
	done

	return 0
}

function backup_define_gui {
	local PATH_="/"
	local LAST_PATH="$PATH_"
	declare -i RET_VAL
	local VALUE

	while true
	do
		if is_it_local "$SERVER_NAME"
		then
			if ! folders_and_files "$PATH_"i
			then
				error_message "$FOLDERS_AND_FILES_ERROR" "FOLDERS_AND_FILES_ERROR"
				PATH_="$LAST_PATH"
				continue
			fi
		else
			echo "WIP"
		fi

		dialog 	--begin 13 30 \
			--title "Directories in $PATH_" \
			--infobox "${FOLDERS_[*]}" 30 50 \
			--and-widget \
			--begin 13 130 \
			--title "Files in $PATH_" \
			--infobox "${FILES_[*]}" 30 50 \
			--and-widget \
			--extra-button \
			--extra-label "SEARCH" \
			--title "$PROGRAM_TITLE" \
			--inputbox "Path" 0 0 "$PATH_" \
			--output-fd 1 \
			> "$TMP_INFO"
		RET_VAL=$?
		if ((RET_VAL == 1))
		then
			return 1
		elif ((RET_VAL == 0))
		then
			BACKUP_VAL="$(cat "$TMP_INFO")"

			if ! verify_path "$BACKUP_VAL"
			then
				error_message "$VERIFY_PATH_ERROR" "VERIFY_PATH_ERROR"
				unset BACKUP_VAL
				continue
			else
				break
			fi
		fi
		
		LAST_PATH="$PATH_"
		PATH_=$(cat "$TMP_INFO")
	done

	return 0
}

function test_server {
	dialog 	--infobox "Please wait, generating log with results..." 0 0
	
	if check_protocol_name "$SERVER_NAME" "IPERF"
	then
		error_message "Please, define an IPERF port!"
		return 1
	fi

	if ! pick_protocol_info "$SERVER_NAME" "IPERF"
	then
		error_message "Error.."
	fi
	

	local PROTOCOL_INFO
	for PROTOCOL_INFO in $PICK_PROTOCOL_INFO
	do
		# Hopes for three types of protocol info and then
		# parse then in the following order
		if [ -z "$IPERF_NAME" ]
		then
			local IPERF_NAME="$PROTOCOL_INFO"
		elif [ -z "$IPERF_PORT" ]
		then
			local IPERF_PORT="$PROTOCOL_INFO"
		else
			local IPERF_INT_PROT="$PROTOCOL_INFO"
		fi
	done

	if [ "$IPERF_INT_PROT" = "UDP" ]
	then
		local IPERF_UDP="-u"
	fi
	
	log_to_file "Starting test for the server $SERVER_NAME"

	log_to_file "$(iperf3 "$IPERF_UDP" -c "$SERVER_IP" -p "$IPERF_PORT" 2>&1)"

	log_to_file "$(ping -c 6 "$SERVER_IP" 2>&1 | grep "rtt" 2>&1)"

	list_all_protocols "$SERVER_NAME"

	if [ -z "$LIST_ALL_PROTOCOLS_VAR" ]
	then
		LIST_ALL_PROTOCOLS_VAR="$(echo -e "None\n0\nNULL")"
	fi
	
	declare -i TMP=0
	local PROTOCOL_PORT_INT_PORT
	declare -A PORT_INFO

	local TCP_PORTS=""
	local UDP_PORTS=""

	for PROTOCOL_PORT_INT_PORT in $LIST_ALL_PROTOCOLS_VAR
	do
		((++TMP))
		
		if ((TMP == 1))
		then
			if [ "$PROTOCOL_PORT_INT_PORT" = "SSH" ]
			then
				TMP=0
				declare -i SSH_TIME=1
			elif ((SSH_TIME))
			then
				continue
			fi
			continue
		else
			if [ -z "$PORT_NUMBER" ]
			then
				local PORT_NUMBER="$PROTOCOL_PORT_INT_PORT"
			else
				if [ "$PROTOCOL_PORT_INT_PORT" = "UDP" ]
				then
					if [ -z "$UDP_PORTS" ]
					then
						UDP_PORTS="$PORT_NUMBER"
					else
						UDP_PORTS="${UDP_PORTS},$PORT_NUMBER"
					fi
				elif [ "$PROTOCOL_PORT_INT_PORT" = "TCP" ]
				then
					if [ -z "$TCP_PORTS" ]
					then
						TCP_PORTS="$PORT_NUMBER"
					else
						TCP_PORTS="${TCP_PORTS},$PORT_NUMBER"
					fi
				fi
				unset PORT_NUMBER
				TMP=0
			fi
		fi
	done

	log_to_file "$(nmap -sUT "$SERVER_IP" -p "T:${TCP_PORTS},U:${UDP_PORTS}" 2>&1)"

	return 0
}

function add_server_gui {
	# A menu to create the server
	# It consists of 2 input menu
	# the name and the IP of the server

	local SERVER_NAME=""
	local SERVER_IP=""

	SERVER_CAMPS[0]="Server Name"
	SERVER_CAMPS[1]="Server IP"

	while true
	do	 
		dialog 	--clear \
			--title "$PROGRAM_TITLE" \
			--inputmenu "Server Add" 0 0 10 \
			"${SERVER_CAMPS[0]}" "$SERVER_NAME" \
			"${SERVER_CAMPS[1]}" "$SERVER_IP" \
			--output-fd 1 \
			> "$TMP_INFO"

		declare -i RET_VAL=$?

		local RESULT=$(cat "$TMP_INFO")
		rm "$TMP_INFO"

		if [[ $RESULT =~ "RENAMED" ]]
		then
			declare -i SECS=0
			local TMP_VAL
			for TMP_VAL in $RESULT
			do
				if ((SECS == 1)) || ((SECS == 2))
				then
					if [ -z $CAMPINFO ]
					then
						local CAMPINFO="$TMP_VAL"
					else
						CAMPINFO="$CAMPINFO $TMP_VAL"
					fi
				elif ((SECS == 3))
				then
					local NEWVAL="$TMP_VAL"
				elif ((SECS > 3))
				then
					NEWVAL="$NEWVAL $TMP_VAL"
				fi

				((++SECS))
			done

			unset TMP_VAL
			unset SECS

			dialog 	--clear \
				--title "$PROGRAM_TITLE" \
				--msgbox "$CAMPINFO" 0 0
			
			case $CAMPINFO in
				"${SERVER_CAMPS[0]}")
					SERVER_NAME="$NEWVAL"
					;;

				"${SERVER_CAMPS[1]}")
					SERVER_IP="$NEWVAL"
					;;
				*)
					error_message "How?!"	
					return 1
			esac
			
			unset NEWVAl
			unset CAMPINFO

			continue
		elif ((RET_VAL == 0))
		then
			if ! add_server "$SERVER_NAME" "$SERVER_IP"
			then
				error_message "$ADD_SERVER_ERROR" "ADD_SERVER_ERROR"
				return 1
			fi

			break
		else
			return 1
		fi	
	done

	return 0
}

function change_server_gui {
	# A menu to create the server
	# It consists of 2 input menu
	# the name and the IP of the server

	local TMP_SERVER_NAME="$SERVER_NAME"
	local TMP_SERVER_IP="$SERVER_IP"

	local MAIN_SERVER_NAME="$SERVER_NAME"
	local MAIN_SERVER_IP="$SERVER_IP"

	SERVER_CAMPS[0]="Server Name"
	SERVER_CAMPS[1]="Server IP"

	while true
	do	 
		dialog 	--clear \
			--title "$PROGRAM_TITLE" \
			--inputmenu "Server Add" 0 0 10 \
			"${SERVER_CAMPS[0]}" "$TMP_SERVER_NAME" \
			"${SERVER_CAMPS[1]}" "$TMP_SERVER_IP" \
			--output-fd 1 \
			> "$TMP_INFO"

		declare -i RET_VAL=$?

		local RESULT=$(cat "$TMP_INFO")
		rm "$TMP_INFO"

		if [[ $RESULT =~ "RENAMED" ]]
		then
			declare -i SECS=0
			local TMP_VAL
			for TMP_VAL in $RESULT
			do
				if ((SECS == 1)) || ((SECS == 2))
				then
					if [ -z $CAMPINFO ]
					then
						local CAMPINFO="$TMP_VAL"
					else
						CAMPINFO="$CAMPINFO $TMP_VAL"
					fi
				elif ((SECS == 3))
				then
					local NEWVAL="$TMP_VAL"
				elif ((SECS > 3))
				then
					NEWVAL="$NEWVAL $TMP_VAL"
				fi

				((++SECS))
			done

			unset TMP_VAL
			unset SECS
			
			case $CAMPINFO in
				"${SERVER_CAMPS[0]}")
					TMP_SERVER_NAME="$NEWVAL"
					;;

				"${SERVER_CAMPS[1]}")
					TMP_SERVER_IP="$NEWVAL"
					;;
				*)
					error_message "How?!"
					return 1
			esac
			
			unset NEWVAl
			unset CAMPINFO

			continue
		elif ((RET_VAL == 0))
		then
			if [ "$TMP_SERVER_NAME" != "$MAIN_SERVER_NAME" ] && [ "$TMP_SERVER_IP" != "$MAIN_SERVER_IP" ]
			then
				error_message "You can't change both name and ip, create a new server!"
				return 1
			elif [ "$TMP_SERVER_NAME" = "$MAIN_SERVER_NAME" ] && [ "$TMP_SERVER_IP" = "$MAIN_SERVER_IP" ]
			then
				return 1
			elif [ "$TMP_SERVER_NAME" != "$MAIN_SERVER_NAME" ]
			then
				declare -i TYPE=1
			elif [ "$TMP_SERVER_IP" != "$MAIN_SERVER_IP" ]
			then
				declare -i TYPE=0
			fi

			if ! change_server "$TMP_SERVER_NAME" "$TMP_SERVER_IP" "$TYPE"
			then
				return 1
			fi
			break
		else
			return 1
		fi	
	done

	SERVER_NAME="$TMP_SERVER_NAME"
	SERVER_IP="$TMP_SERVER_IP"

	return 0
}

function remove_server_gui {
	# Deletes the passed server, but warns and give useful info
	# through the dialog
	# Arguments:
	# First > server name (well, to delete the server :P)

	local SERVER_NAME="$1"

	dialog 	--clear \
		--title "$PROGRAM_TITLE" \
		--yesno "Do you want to delete the server $SERVER_NAME?" 0 0
	
	declare -i RET_VAL=$?

	if ((RET_VAL))
	then
		return 1
	fi
	
	if ! remove_server "$SERVER_NAME"
	then
		error_message "$REMOVE_SERVER_ERROR" "REMOVE_SERVER_ERROR"
		return 1
	fi

	return 0
}

function protocol_menu {
	# Creates a menu with all the menus available
	# if there's none, a NONE protocol will appear
	# All the protocols are taken from the servers file
	# Arguments:
	# First > server name (caracteristic of the protocol management)


	local SERVER_NAME=$1

	while true
	do
		unset PORT_INFO
		unset FIRST_TIME

		list_all_protocols "$SERVER_NAME"

		if [ -z "$LIST_ALL_PROTOCOLS_VAR" ]
		then
			LIST_ALL_PROTOCOLS_VAR="$(echo -e "None\n0\nNULL")"
		fi
		
		declare -i TMP=0
		local PROTOCOL_PORT_INT_PORT
		declare -A PORT_INFO

		for PROTOCOL_PORT_INT_PORT in $LIST_ALL_PROTOCOLS_VAR
		do
			((++TMP))
			
			if ((TMP == 1))
			then
				if [ "$PROTOCOL_PORT_INT_PORT" = "SSH" ]
				then
					declare -i SSH_TIME=1
				elif ((SSH_TIME))
				then
					# Takes advantage of this iteration to pick ssh info
					# But, there's an original function for this task

					local USER_NAME="$(cut -d "-" -f 2 <<< "$PROTOCOL_PORT_INT_PORT")"
					local SSH_TYPE="$(cut -d "-" -f 1 <<< "$PROTOCOL_PORT_INT_PORT")"
					unset SSH_TIME
					TMP=0
					continue
				fi

				local NAME="$PROTOCOL_PORT_INT_PORT"
				
				PORT_INFO["$NAME"]


			else
				if [ -z "$FIRST_TIME" ]
				then
					local FIRST_TIME="$PROTOCOL_PORT_INT_PORT"
				else
					PORT_INFO["$NAME"]="${FIRST_TIME}_$PROTOCOL_PORT_INT_PORT"
					unset FIRST_TIME
					TMP=0
				fi
			fi
		done

		dialog 	--clear \
			--title "$PROGRAM_TITLE" \
			--ok-label "MODIFY" \
			--cancel-label "BACK" \
			--extra-button \
			--extra-label "ADD" \
			--help-button \
			--help-label "REMOVE" \
			--menu "Protocols: $SERVER_NAME" 0 0 0 \
			$(for TO_PRINT in ${!PORT_INFO[*]};do echo "$TO_PRINT"; echo "${PORT_INFO["$TO_PRINT"]}";done) \
			--output-fd 1 \
			> "$TMP_INFO"
		
		declare -i EXIT_STATUS=$?

		local RESULT=$(cat "$TMP_INFO")

		case $EXIT_STATUS in
			1)
				return 1
				;;
			0)
				local PORT=$(cut -d "_" -f 1 <<< ${PORT_INFO["$RESULT"]})
				local INT_PROTOCOL=$(cut -d "_" -f 2 <<< ${PORT_INFO["$RESULT"]})

				modify_protocol_gui "$SERVER_NAME" "$RESULT" "$PORT" "$INT_PROTOCOL" "$SSH_TYPE" "$USER_NAME"
				continue
				;;
			2)
				local PROTOCOL=$(cut -d " " -f 2 <<< $RESULT)

				remove_protocol_gui "$SERVER_NAME" "$PROTOCOL"

				continue
				;;
			3)
				add_protocol_gui "$SERVER_NAME"

				continue
				;;
			*)
				dialog --msgbox "Something big happened, leaving... $EXIT_STATUS" 0 0
				return 1
		esac
	done
			
	return 0
}

function modify_protocol_gui {
	# Generates a dynamic add_protocol_gui but with
	# the input forms and menus containing default values
	# which were passesed to this function
	# Arguments:
	# First > name server (necessary to pin point from that server only)
	# Second > protocol name
	# Third > protocol port
	# Fourth > internet protocol
	# Fifth > ssh type(Password(0) or Public key(1))
	# Sixth > The user to be used to connect with ssh
	# Fifth and Sixth applies only when the protocol name is SSH
	# Yes, it's case sensitive...

	local NAME_SERVER="$1"
	
	local STARTUP_PROTOCOL="$2"
	declare -i STARTUP_PORT="$3"

	local PROTOCOL="$2"
	declare -i PORT="$3"
	declare -i INT_PROTOCOL="$4"
	local SSH_TYPE="$5"
	local USER_NAME="$6"
	
	PROTOCOL_CAMPS[0]="Protocol Name"
	PROTOCOL_CAMPS[1]="Protocol Port"

	while true
	do	 
		dialog 	--clear \
			--title "$PROGRAM_TITLE" \
			--inputmenu "$NAME_SERVER Modify Protocol $PROTOCOL" 0 0 10 \
			"${PROTOCOL_CAMPS[0]}" "$PROTOCOL" \
			"${PROTOCOL_CAMPS[1]}" "$PORT" \
			--output-fd 1 \
			> "$TMP_INFO"

		declare -i RET_VAL=$?

		local RESULT=$(cat "$TMP_INFO")
		rm "$TMP_INFO"

		if [[ $RESULT =~ "RENAMED" ]]
		then
			declare -i SECS=0
			local TMP_VAL
			for TMP_VAL in $RESULT
			do
				if ((SECS == 1)) || ((SECS == 2))
				then
					if [ -z $CAMPINFO ]
					then
						local CAMPINFO="$TMP_VAL"
					else
						CAMPINFO="$CAMPINFO $TMP_VAL"
					fi
				elif ((SECS == 3))
				then
					local NEWVAL="$TMP_VAL"
				elif ((SECS > 3))
				then
					NEWVAL="$NEWVAL $TMP_VAL"
				fi

				((++SECS))
			done

			unset TMP_VAL
			unset SECS
			
			case $CAMPINFO in
				"${PROTOCOL_CAMPS[0]}")
					PROTOCOL="$NEWVAL"
					;;

				"${PROTOCOL_CAMPS[1]}")
					PORT="$NEWVAL"
					;;
				*)
					error_message "HOW?!"
					return 1
			esac
			
			unset NEWVAl
			unset CAMPINFO

			continue

		elif ((RET_VAL == 0))
		then
			declare -i DO_NOT_REPEAT
			declare -i DO_CONTINUE=1
			if [ "$PROTOCOL" = "SSH" ] && [ "$SERVER_NAME" != "LOCAL" ]
			then
				DO_NOT_REPEAT=0
				while true
				do
					dialog 	--clear \
						--title "$PROGRAM_TITLE" \
						--ok-label "SELECT" \
						--colors \
						--default-item "$SSH_TYPE"
						--cancel-label "BACK" \
						--menu "$SERVER_NAME SSH Connection Type" 0 0 0 \
						"1" "Public key - \Z2Secure" \
						"0" "Password - \Z1Insecure" \
						--output-fd 1 \
						> "$TMP_INFO"

					RET_VAL=$?
					local SSH_TYPE=$(cat "$TMP_INFO")

					if ((RET_VAL))
					then
						break
					fi
					while true
					do
						dialog 	--clear \
							--title "$PROGRAM_TITLE" \
							--colors \
							--cancel-label "BACK" \
							--inputbox "The username to connect as - \Z1IT NEED TO HAVE ROOT PERMISSION" 0 0 "$USER_NAME" \
							--output-fd 1 \
							> "$TMP_INFO"

						RET_VAL=$?
						local USER_NAME="$(cat "$TMP_INFO")"

						if ((RET_VAL))
						then
							break
						fi

						dialog 	--clear \
							--title "$PROGRAM_TITLE" \
							--ok-label "SELECT" \
							--default-item "$INT_PROTOCOL" \
							--cancel-label "BACK" \
							--menu "$SERVER_NAME Internet Protocol" 0 0 0 \
							"0" "TCP" \
							"1" "UDP" \
							--output-fd 1 \
							> "$TMP_INFO"

						RET_VAL=$?
						RESULT=$(cat "$TMP_INFO")

						if ((RET_VAL))
						then
							continue
						else
							DO_CONTINUE=0
							break
						fi
					done
					if ((! RET_VAL))
					then
						break
					fi
				done
			else
				DO_NOT_REPEAT=1
			fi
			
			if ((DO_NOT_REPEAT))
			then
				dialog 	--clear \
					--title "$PROGRAM_TITLE" \
					--ok-label "SELECT" \
					--cancel-label "BACK" \
					--menu "$SERVER_NAME Internet Protocol" 0 0 0 \
					"0" "TCP" \
					"1" "UDP" \
					--output-fd 1 \
					> "$TMP_INFO"
				
				RET_VAL=$?
				RESULT=$(cat "$TMP_INFO")
			fi

			if ((RET_VAL)) && ((DO_CONTINUE))
			then
				continue
			else
				case $RESULT in
					0)
						local INT_PROTOCOL="TCP"
						;;
					1)
						local INT_PROTOCOL="UDP"
				esac

				if [ "$STARTUP_PORT" != "$PORT" ] && [ "$STARTUP_PROTOCOL" != "$PROTOCOL" ]
				then
					error_message "It's impossible to modify both Protocol name and port! Create a new one!"
					continue
				elif [ "$STARTUP_PORT" != "$PORT" ]
				then
					declare -i STATUS_CHANGE=1
				elif [ "$STARTUP_PROTOCOL" != "$PROTOCOL" ]
				then
					declare -i STATUS_CHANGE=0
				fi

				if ! modify_protocol "$SERVER_NAME" "$PROTOCOL" "$PORT" "$INT_PROTOCOL" "$STATUS_CHANGE" "$SSH_TYPE" "$USER_NAME"
				then
					error_message "$MODIFY_PROTOCOL_ERROR" "MODIFY_PROTOCOL_ERROR"
					return 1
				fi
				break
			fi
		else
			return 1
		fi	
	done

	return 0
}

function remove_protocol_gui {
	# Removes a protocol from the server while
	# giving some useful info
	# Arguments:
	# First > name server (to pin point the deletion)
	# Second > protocol name (Uhh, do I need to explain?)

	local NAME_SERVER="$1"
	local PROTOCOL="$2"

	dialog 	--clear \
		--title "$PROGRAM_TITLE" \
		--yesno "Are you sure to delete the protocol $PROTOCOL from $NAME_SERVER?" 0 0
	
	declare -i RET_VAL=$?

	if ((RET_VAL))
	then
		return 1
	else
		if ! remove_protocol "$NAME_SERVER" "$PROTOCOL"
		then
			error_message "$REMOVE_PROTOCOL_ERROR" "REMOVE_PROTOCOL_ERROR"
			return 1
		fi
	fi

	return 0
}

function add_protocol_gui {
	# Adds a protocol to the server with input menus
	# Arguments:
	# First > name server

	local NAME_SERVER="$1"

	local PROTOCOL=""
	local PORT=""
	
	PROTOCOL_CAMPS[0]="Protocol Name"
	PROTOCOL_CAMPS[1]="Protocol Port"

	while true
	do	 
		dialog 	--clear \
			--title "$PROGRAM_TITLE" \
			--inputmenu "$NAME_SERVER Add Protocol" 0 0 10 \
			"${PROTOCOL_CAMPS[0]}" "$PROTOCOL" \
			"${PROTOCOL_CAMPS[1]}" "$PORT" \
			--output-fd 1 \
			> "$TMP_INFO"

		declare -i RET_VAL=$?

		local RESULT=$(cat "$TMP_INFO")
		rm "$TMP_INFO"

		if [[ $RESULT =~ "RENAMED" ]]
		then
			declare -i SECS=0
			local TMP_VAL
			for TMP_VAL in $RESULT
			do
				if ((SECS == 1)) || ((SECS == 2))
				then
					if [ -z $CAMPINFO ]
					then
						local CAMPINFO="$TMP_VAL"
					else
						CAMPINFO="$CAMPINFO $TMP_VAL"
					fi
				elif ((SECS == 3))
				then
					local NEWVAL="$TMP_VAL"
				elif ((SECS > 3))
				then
					NEWVAL="$NEWVAL $TMP_VAL"
				fi

				((++SECS))
			done

			unset TMP_VAL
			unset SECS

			dialog 	--clear \
				--title "$PROGRAM_TITLE" \
				--msgbox "$CAMPINFO" 0 0
			
			case $CAMPINFO in
				"${PROTOCOL_CAMPS[0]}")
					PROTOCOL="$NEWVAL"
					;;

				"${PROTOCOL_CAMPS[1]}")
					PORT="$NEWVAL"
					;;
				*)
					error_message "HOW?!"
					return 1
			esac
			
			unset NEWVAl
			unset CAMPINFO

			continue
		elif ((RET_VAL == 0))
		then
			declare -i DO_NOT_REPEAT
			declare -i DO_CONTINUE=1
			if [ "$PROTOCOL" = "SSH" ] && [ "$SERVER_NAME" != "LOCAL" ]
			then
				DO_NOT_REPEAT=0
				while true
				do
					dialog 	--clear \
						--title "$PROGRAM_TITLE" \
						--ok-label "Select" \
						--colors \
						--cancel-label "Back" \
						--menu "$SERVER_NAME SSH Connection Type" 0 0 0 \
						"1" "Public key - \Z2Secure" \
						"0" "Password - \Z1Insecure" \
						--output-fd 1 \
						> "$TMP_INFO"

					RET_VAL=$?
					local SSH_TYPE=$(cat "$TMP_INFO")

					if ((RET_VAL))
					then
						break
					fi
					
					while true
					do
						dialog 	--clear \
							--title "$PROGRAM_TITLE" \
							--colors \
							--cancel-label "Back" \
							--inputbox "The username to connect as - \Z1IT NEED TO HAVE ROOT PERMISSION" 0 0 \
							--output-fd 1 \
							> "$TMP_INFO"

						RET_VAL=$?

						local USER_NAME="$(cat "$TMP_INFO")"

						if ((RET_VAL))
						then
							break
						fi

						dialog 	--clear \
							--title "$PROGRAM_TITLE" \
							--ok-label "Select" \
							--cancel-label "Back" \
							--menu "$SERVER_NAME Internet Protocol" 0 0 0 \
							"0" "TCP" \
							"1" "UDP" \
							--output-fd 1 \
							> "$TMP_INFO"

						RET_VAL=$?
						RESULT=$(cat "$TMP_INFO")

						if ((RET_VAL))
						then
							continue
						else
							DO_CONTINUE=0
							break
						fi
					done
					if ((! RET_VAL))
					then
						break
					fi
				done
			else
				DO_NOT_REPEAT=1
				SSH_USER=""
				SSH_TYPE=""
			fi
			
			if ((DO_NOT_REPEAT))
			then
				dialog 	--clear \
					--title "$PROGRAM_TITLE" \
					--ok-label "Select" \
					--cancel-label "Back" \
					--menu "$SERVER_NAME Internet Protocol" 0 0 0 \
					"0" "TCP" \
					"1" "UDP" \
					--output-fd 1 \
					> "$TMP_INFO"
				
				RET_VAL=$?
				RESULT=$(cat "$TMP_INFO")
			fi
			
			RET_VAL=$?
			RESULT=$(cat "$TMP_INFO")

			if ((RET_VAL))
			then
				continue
			else
				case $RESULT in
					0)
						local INT_PROTOCOL="TCP"
						;;
					1)
						local INT_PROTOCOL="UDP"
				esac

				if ! add_protocol "$SERVER_NAME" "$PROTOCOL" "$PORT" "$INT_PROTOCOL" "$SSH_TYPE" "$USER_NAME"
				then
					error_message "$ADD_PROTOCOL_ERROR" "ADD_PROTOCOL_ERROR"
					return 1
				fi

				break
			fi
		else
			return 1
		fi	
	done

	return 0
}

function in_server_menu {
	# Creates a menu for the selected server
	# after the selection of one from server_menu
	# Arguments:
	# First > server name
	# Second > server IP

	while true
	do
		unset SSH_TYPE_ERROR
		ssh_type "$SERVER_NAME"
		declare -i SSH_PORT="$(cut -d " " -f 1 <<< "$SSH_TYPE_VAL")"
		local SSH_TMP="$(cut -d " " -f 3 <<< "$SSH_TYPE_VAL")"
		local SSH_USER="$(cut -d "_" -f 2 <<< $SSH_TMP)"
		declare -i SSH_TYPE="$(cut -d "_" -f 1 <<< $SSH_TMP)"
		
		if ! is_it_local "$SERVER_NAME"
		then
			if [ -z "$PASSWORD" ]
			then
				if [ -z "$SSH_TYPE_ERROR" ]
				then
					if ((SSH_TYPE == 0))
					then
						while true
						do
							dialog 	--clear \
								--title "$PROGRAM_TITLE" \
								--extra-button \
								--extra-label "INSECURE-BOX" \
								--no-cancel \
								--passwordbox "Password for $SSH_USER in $SERVER_NAME" 0 0 \
								--output-fd 1 \
								> "$TMP_INFO"
							declare -i RET_VAL="$?"

							if ((RET_VAL == 3))
							then
								dialog 	--clear \
									--title "$PROGRAM_TITLE" \
									--extra-button \
									--extra-label "SECURE-BOX" \
									--no-cancel \
									--insecure \
									--passwordbox "Password for $SSH_USER in $SERVER_NAME" 0 0 \
									--output-fd 1 \
									> "$TMP_INFO"
								RET_VAL=$?
								if ((RET_VAL == 3))
								then
									continue
								else
									break
								fi
							else
								break
							fi

						done
						
						local PASSWORD="$(cat "$TMP_INFO")"
						rm "$TMP_INFO"
					fi
				fi
			fi

			dialog --infobox "Please wait, checking a few things..." 0 0
			if [ -z "$SSH_TYPE_ERROR" ]
			then
				if ! check_com "$SSH_TYPE" "$SSH_USER" "$SERVER_IP" "$SSH_PORT" "$PASSWORD"
				then
					error_message "$CHECK_COM_ERROR" "CHECK_COM_ERROR"
					return 1
				fi
			fi

		fi

		
		dialog 	--clear \
			--title "$PROGRAM_TITLE" \
			--menu "$SERVER_NAME" 0 0 0 \
			"0" "Protocol Management" \
			"1" "Test Server Speed" \
			"2" "User Management" \
			"3" "Backup Management" \
			"4" "Modify Server Info" \
			--output-fd 1 \
			> "$TMP_INFO"
		
		declare -i RET_VAL=$?
		declare -i VALUE=$(cat $TMP_INFO)
	
		if ((RET_VAL))
		then
			break
		fi
		
		unset SSH_TYPE_ERROR

		function check {
			if [ "$SERVER_NAME" = "LOCAL" ]
			then
				$1
			elif [ -z "$SSH_TYPE_ERROR" ] 
			then
				unset SSH_TYPE_VAL
				$1 "$2" "$SSH_TYPE" "$SSH_USER" "$PASSWORD"
			else
				dialog 	--clear \
					--title "$PROGRAM_TITLE" \
					--msgbox "$SSH_TYPE_ERROR" \
					--output-fd 1
				return 1
			fi

			return 0
		}

		case $VALUE in
			0)
				protocol_menu "$SERVER_NAME"

				continue
				;;
			1)
				test_server
				continue
				;;
			2)
				check "user_menu_gui"

				continue
				;;
			3)
				backup_management_gui
				continue
				;;
			4)
				if is_it_local "$SERVER_NAME"
				then
					error_message "It's not possible to modify the local server!" ""
				else
					change_server_gui
				fi

				continue
				;;
			*)
				return 1
		esac
	done

	return 0
}

function modify_user_gui {
	# Modify the user by generating dynamically
	# all the forms with the passed arguments
	# Arguments:
	# First > user name (It uses a function called pick_user_info which
	# creates an array that have all the info about the user)
	
	local TMP_VAL="$1"
	
	if is_it_local "$NAME_SERVER"
	then
		if ! pick_user_info "$TMP_VAL"
		then
			error_message "$SEND_COM_ERROR" "SEND_COM_ERROR"
			return 1
		fi
	else
		if ! send_com "$SSH_TYPE" "$SSH_USER" "$SERVER_IP" "$SSH_PORT" "$PASSWORD" "pick_user_info \"$TMP_VAL\""
		then
			error_message "$SEND_COM_ERROR" "SEND_COM_ERROR"
			return 1

		fi
		declare -A PICK_USER_INFO_VAL
		local NULL
	
		for TMP_NON_ARRAY in $(echo -e "$SEND_COM_VAL")
		do
			local NAME="$(cut -d ":" -f 1 <<< $TMP_NON_ARRAY)"
			local VALUE="$(cut -d ":" -f 2 <<< $TMP_NON_ARRAY)"
			PICK_USER_INFO_VAL["$NAME"]="$VALUE"
		done
		unset NAME
		unset VALUE
		unset NULL
	fi

	
	local MAIN_USERNAME=${PICK_USER_INFO_VAL["NAME"]}
	local USERNAME="${PICK_USER_INFO_VAL["NAME"]}"
	local USERDIR="${PICK_USER_INFO_VAL["HOME_DIR"]}"
	local USERGROUPS="${PICK_USER_INFO_VAL["GROUPS"]}"
	local USERTERMINAL="${PICK_USER_INFO_VAL["SHELL"]}"

	declare -a USER_CAMPS
	declare -i FIRST_TIME_NAME=1
	declare -i CHANGE_NAME=1
	USER_CAMPS[0]="User Name"
	USER_CAMPS[1]="User Dir"
	USER_CAMPS[2]="User Groups"
	USER_CAMPS[3]="User Terminal"

	while true
	do	 
		dialog 	--clear \
			--title "$PROGRAM_TITLE" \
			--inputmenu "User Info" 0 0 10 \
			"${USER_CAMPS[0]}" "$USERNAME" \
			"${USER_CAMPS[1]}" "$USERDIR" \
			"${USER_CAMPS[2]}" "$USERGROUPS" \
			"${USER_CAMPS[3]}" "$USERTERMINAL" \
			--output-fd 1 \
			> "$TMP_INFO"

		declare -i RET_VAL=$?

		local RESULT=$(cat "$TMP_INFO")
		rm "$TMP_INFO"

		if [[ $RESULT =~ "RENAMED" ]]
		then
			declare -i SECS=0
			local TMP_VAL
			for TMP_VAL in $RESULT
			do
				if ((SECS == 1)) || ((SECS == 2))
				then
					if [ -z $CAMPINFO ]
					then
						local CAMPINFO="$TMP_VAL"
					else
						CAMPINFO="$CAMPINFO $TMP_VAL"
					fi
				elif ((SECS == 3))
				then
					local NEWVAL="$TMP_VAL"
				elif ((SECS > 3))
				then
					NEWVAL="$NEWVAL $TMP_VAL"
				fi

				((++SECS))
			done

			unset TMP_VAL
			unset SECS

			dialog 	--clear \
				--title "$PROGRAM_TITLE" \
				--msgbox "$CAMPINFO" 0 0
			
			case $CAMPINFO in
				"${USER_CAMPS[0]}")
					USERNAME="$NEWVAL"

					if ((FIRST_TIME_NAME))
					then
						USERDIR="/home/$USERNAME"
						FIRST_TIME_NAME=0
					fi
					;;

				"${USER_CAMPS[1]}")
					USERDIR="$NEWVAL"

					if ((FIRST_TIME_NAME))
					then
						FIRST_TIME_NAME=0
					fi
					;;

				"${USER_CAMPS[2]}")
					USERGROUPS="$NEWVAL"
					;;

				"${USER_CAMPS[3]}")
					USERTERMINAL="$NEWVAL"
					;;

				*)
					dialog	--clear \
						--msgbox "Unknown error!" 0 0
					
					return 1
			esac
			
			unset NEWVAl
			unset CAMPINFO

			continue
		elif ((RET_VAL == 0))
		then
			dialog 	--clear \
				--title "$PROGRAM_TITLE" \
				--msgbox "USER=$USERNAME\nUSERDIR=$USERDIR\nUSERGROUPS=$USERGROUPS\nUSERTERMINAL=$USERTERMINAL" 0 0
			if is_it_local "$SERVER_NAME"
			then
				if ! modify_user "$MAIN_USERNAME" "$USERNAME" "$USERDIR" "$USERGROUPS" "$USERTERMINAL"
				then
					error_message "$SEND_COM_ERROR" "SEND_COM_ERROR"
					return 1
				fi
			else
				if ! send_com "$SSH_TYPE" "$SSH_USER" "$SERVER_IP" "$SSH_PORT" "$PASSWORD" "modify_user \"$MAIN_USERNAME\" \"$USERNAME\" \"$USERDIR\" \"$USERGROUPS\" \"$USERTERMINAL\""
				then
					error_message "$SEND_COM_ERROR" "SEND_COM_ERROR"
					return 1
				fi
			fi

			dialog 	--clear \
				--title "$PROGRAM_TITLE" \
				--msgbox "User modified with sucess!" 0 0
			
			break
		else
			dialog 	--clear \
				--title "$PROGRAM_TITLE" \
				--msgbox "Leaving program!" 0 0
			return 1
		fi

		return 0
			
	done


	return 0
}

function add_user_gui {
	# Creates the user by filling an input menu
	
	local USERNAME=""
	local USERDIR="/home/"
	local USERGROUPS=""
	local USERTERMINAL="/bin/bash"

	declare -a USER_CAMPS
	declare -i FIRST_TIME_NAME=1
	USER_CAMPS[0]="User Name"
	USER_CAMPS[1]="User Dir"
	USER_CAMPS[2]="User Groups"
	USER_CAMPS[3]="User Terminal"

	while true
	do	 
		dialog 	--clear \
			--title "$PROGRAM_TITLE" \
			--inputmenu "User Info" 0 0 10 \
			"${USER_CAMPS[0]}" "$USERNAME" \
			"${USER_CAMPS[1]}" "$USERDIR" \
			"${USER_CAMPS[2]}" "$USERGROUPS" \
			"${USER_CAMPS[3]}" "$USERTERMINAL" \
			--output-fd 1 \
			> "$TMP_INFO"

		declare -i RET_VAL=$?

		local RESULT=$(cat "$TMP_INFO")
		rm "$TMP_INFO"

		if [[ $RESULT =~ "RENAMED" ]]
		then
			declare -i SECS=0
			local TMP_VAL
			for TMP_VAL in $RESULT
			do
				if ((SECS == 1)) || ((SECS == 2))
				then
					if [ -z $CAMPINFO ]
					then
						local CAMPINFO="$TMP_VAL"
					else
						CAMPINFO="$CAMPINFO $TMP_VAL"
					fi
				elif ((SECS == 3))
				then
					local NEWVAL="$TMP_VAL"
				elif ((SECS > 3))
				then
					NEWVAL="$NEWVAL $TMP_VAL"
				fi

				((++SECS))
			done

			unset TMP_VAL
			unset SECS

			dialog 	--clear \
				--title "$PROGRAM_TITLE" \
				--msgbox "$CAMPINFO" 0 0
			
			case $CAMPINFO in
				"${USER_CAMPS[0]}")
					USERNAME="$NEWVAL"

					if ((FIRST_TIME_NAME))
					then
						USERDIR="/home/$USERNAME"
						FIRST_TIME_NAME=0
					fi
					;;
				"${USER_CAMPS[1]}")
					USERDIR="$NEWVAL"

					if ((FIRST_TIME_NAME))
					then
						FIRST_TIME_NAME=0
					fi
					;;
				"${USER_CAMPS[2]}")
					USERGROUPS="$NEWVAL"
					;;
				"${USER_CAMPS[3]}")
					USERTERMINAL="$NEWVAL"
					;;
				*)
					dialog	--clear \
						--msgbox "Unknown error!" 0 0
					
					return 1
			esac
			
			unset NEWVAl
			unset CAMPINFO

			continue
		elif ((RET_VAL == 0))
		then
			dialog 	--clear \
				--title "$PROGRAM_TITLE" \
				--msgbox "USER=$USERNAME\nUSERDIR=$USERDIR\nUSERGROUPS=$USERGROUPS\nUSERTERMINAL=$USERTERMINAL" 0 0
			if is_it_local "$SERVER_NAME"
			then
				if ! add_user "$USERNAME" "$USERDIR" "$USERGROUPS" "$USERTERMINAL"
				then
					error_message "$ADD_USER_ERROR" "ADD_USER_ERROR"
					return 1
				fi
			else
				if ! send_com "$SSH_TYPE" "$SSH_USER" "$SERVER_IP" "$SSH_PORT" "$PASSWORD" "add_user \"$USERNAME\" \"$USERDIR\" \"$USERGROUPS\" \"$USERTERMINAL\""
				then
					error_message "$SEND_COM_ERROR" "SEND_COM_ERROR"
					return 1
				fi
			fi

			dialog 	--clear \
				--title "$PROGRAM_TITLE" \
				--msgbox "User created with sucess!" 0 0
			
			break
		else
			return 1
		fi

		return 0
			
	done
}

function remove_user_gui {
	# Removes a user from the system
	# Argumets:
	# First > user name

	local USER=$1

	dialog 	--clear \
		--title "$PROGRAM_TITLE" \
		--yesno "Are you sure you want to remove $USER?" 0 0

	declare -i YES_NO=$?

	if ((YES_NO))
	then
		return 1
	else
		if is_it_local "$NAME_SERVER"
		then
			if ! remove_user "$RESULT"
			then
				error_message "$REMOVE_USER_ERROR" "REMOVE_USER_ERROR"

				return 1
			else
				dialog 	--clear \
					--title "$PROGRAM_TITLE" \
					--msgbox "The user $RESULT was removed sucessfully" 0 0
			fi
		else
			if ! send_com "$SSH_TYPE" "$SSH_USER" "$SERVER_IP" "$SSH_PORT" "$PASSWORD" "remove_user \"$RESULT\""
			then
				error_message "$SEND_COM_ERROR" "SEND_COM_ERROR"
			else
				dialog 	--clear \
					--title "$PROGRAM_TITLE" \
					--msgbox "The user $RESULT was removed sucessfully from $SERVER_NAME"
			fi
		fi
	fi

	return 0
}

function is_it_local {
	local NAME_SERVER="$1"

	if [ "$NAME_SERVER" = "LOCAL" ]
	then
		return 0
	else
		return 1
	fi
}

function user_menu_gui {
	# A user menu full of things
	while true
	do
		dialog 	--clear \
			--title "$PROGRAM_TITLE" \
			--menu "Show User Option for $SERVER_NAME" 0 0 0 \
			"0" "ALL" \
			"1" "LOGABLE" \
			"2" "UNLOGABLE" \
			"3" "SEARCH" \
			--output-fd 1 \
			> "$TMP_INFO"

		declare -i RET_VAL=$?

		if ((RET_VAL))
		then
			return 1
		fi

		local USER_SELECTION="$(cat "$TMP_INFO")"

		while true
		do
			case $USER_SELECTION in
				0)
					if is_it_local "$SERVER_NAME"
					then
						if ! show_user "ALL"
						then
							error_message "$SHOW_USER_ERROR" "SHOW_USER_ERROR"
							return 1
						fi
					else
						if ! send_com "$SSH_TYPE" "$SSH_USER" "$SERVER_IP" "$SSH_PORT" "$PASSWORD" "show_user \"ALL\""
						then
							error_message "$SEND_COM_ERROR" "SEND_COM_ERROR"
							return 1
						fi
						SHOW_USER_VAL="$SEND_COM_VAL"
					fi
					;;

				1)
					if is_it_local "$SERVER_NAME"
					then
						if ! show_user "LOGABLE" "" "$SERVER_NAME"
						then
							error_message "$SHOW_USER_ERROR" "SHOW_USER_ERROR"
							return 1
						fi
					else
						if ! send_com "$SSH_TYPE" "$SSH_USER" "$SERVER_IP" "$SSH_PORT" "$PASSWORD" "show_user \"LOGABLE\""
						then
							error_message "$SEND_COM_ERROR" "SEND_COM_ERROR"
							return 1
						fi
						SHOW_USER_VAL="$SEND_COM_VAL"
					fi

					;;

				2)
					if is_it_local "$SERVER_NAME"
					then
						if ! show_user "UNLOGABLE" "" "$SERVER_NAME"
						then
							error_message "$SHOW_USER_ERROR" "SHOW_USER_ERROR"
							return 1
						fi
					else
						if ! send_com "$SSH_TYPE" "$SSH_USER" "$SERVER_IP" "$SSH_PORT" "$PASSWORD" "show_user \"UNLOGABLE\""
						then
							error_message "$SEND_COM_ERROR" "SEND_COM_ERROR"
							return 1
						fi
						SHOW_USER_VAL="$SEND_COM_VAL"
					fi

					;;
				3)
					RESULT=$(
						dialog 	--clear \
							--title "$PROGRAM_TITLE" \
							--inputbox "Name of the user" 0 0 \
							--output-fd 1
					)
					
					if is_it_local "$SERVER_NAME"
					then
						if ! show_user "ALL" "$RESULT"
						then
							error_message "$SHOW_USER_ERROR" "SHOW_USER_ERROR"
							return 1
						fi
					else
						if ! send_com "$SSH_TYPE" "$SSH_USER" "$SERVER_IP" "$SSH_PORT" "$PASSWORD" "show_user \"ALL\" \"$RESULT\""
						then
							error_message "$SEND_COM_ERROR" "SEND_COM_ERROR"
						fi
						SHOW_USER_VAL="$SEND_COM_VAL"
					fi

					;;
				*)
					return 1
			esac
			local USERS=$(awk 'BEGIN {value=0} {print value; print $1; ++value} END{if ($1 == "") print "__NOTHING__"}' <<< $SHOW_USER_VAL)

			dialog 	--clear \
				--title "$PROGRAM_TITLE" \
				--extra-button --extra-label "REMOVE" \
				--ok-label "MODIFY" \
				--cancel-label "BACK" \
				--help-button \
				--help-label "ADD" \
				--menu "Users" 0 0 0 \
				$USERS \
				--output-fd 1 \
				> "$TMP_INFO"
			
			RET_VAL=$?
			
			RESULT=$(cat "$TMP_INFO")

			rm "$TMP_INFO"
			
			declare -i FOUND_IT=0

			for TMPS in $USERS
			do
				if [ "$RESULT" = "$TMPS" ]
				then
					FOUND_IT=1
					continue
				elif ((FOUND_IT))
				then
					RESULT="$TMPS"
					break
				fi
			done

			if ((RET_VAL == 1))
			then
				break
			elif ((RET_VAL == 3))
			then
				remove_user_gui "$RESULT" "$SERVER_NAME"
				continue
			elif ((RET_VAL == 2))
			then
				add_user_gui "$SERVER_NAME"
				continue
			else
				modify_user_gui "$RESULT" "$SERVER_NAME"
				continue
			fi
		done
	done	
}

function error_message {
	dialog 	--clear \
		--title "$PROGRAM_TITLE" \
		--msgbox "$1" 0 0

	unset $2
	return 0
}

# The sparkle of this program

while true
do
	if server_menu
	then
		in_server_menu "$SERVER_NAME" "$SERVER_IP"
	else
		break
	fi
done
