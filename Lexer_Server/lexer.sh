# A small library to parser the server info
# thus, creating a human readable file
# and easy to modify by hand or by using the functions available

# The FILE_SERVER variable specify where the server file is located
# The TMP_DUMP variable specify where temporary files will be created


if [ -z "$FILE_SERVER" ]
then
	echo "There's no server file. Indicate the file with the FILE_SERVER variable!"
	exit 1
elif [ -z "$TMP_INFO" ]
then
	echo "There's no TMP_DUMP variable set, please do it in a suitable location"
	exit 1
fi

function space_finder {
	# Verify for spaces. This helps to avoid hidrance when parsing with awk

	if [[ "$1" =~ [[:space:]] ]]
	then
		SPACE_FINDER_ERROR="A space was found in \"$1\"!"
		return 1	
	fi

	return 0
}

function list_all_servers {
	# A function that creates a global variable called LIST_ALL_SERVERS_VAL
	# containing all the servers in the following order:
	# Name of the server
	# Ip of the server

	LIST_ALL_SERVERS_VAL="$(
	awk '
	{
		if (($1) && ($3))
		{
		print $1
		print $3
		}
	}
	
	' "$FILE_SERVER"
	)"
}

function list_all_protocols {
	# List all protocols whithin a server range.
	# It creates a global variable called LIST_ALL_PROTOCOLS_VAR
	# which contains all the protocols in the following order
	# Protocol name
	# Protocol port
	# Internet protocol

	local SERVERNAME_IP="$1"

	LIST_ALL_PROTOCOLS_VAR="$(
	awk '
	{
		if ((servername == $1) || (servername == $3))
		{
			in_range = 1
		}

		if (in_range)
		{
			split($1, prot_test, "-")
			if((prot_test[1]) && (prot_test[2]) && (prot_test[3]))
			{
				print prot_test[1]
				print prot_test[2]
				print prot_test[3]
				if ($2)
				{
					print $2
				}
			}
			else if ($1 == "}")
			{
				exit 0
			}
		}
	}
	' \
	servername="$SERVERNAME_IP" \
	"$FILE_SERVER")"

	return 0
}

function verify_server_in_file {
	# Verify if a server exist on the file
	# then return true otherwise false
	# Arguments:
	# First > server ip or name

	declare -i EXIST=0
	declare -i DOES_NOT_EXIST=1

	local NAMESERVER_IP=$1

	awk '
	{
		if (nameserver_ip == $1)
		{
			server_exist=1
		}
		else if (nameserver_ip == $3)
		{
			server_exist=1
		}

	}
	
	END {
		if (! server_exist)
		{
			exit 1
		}
	}

	' \
	nameserver_ip="$NAMESERVER_IP" \
	"$FILE_SERVER"

	local PROCESS_RET="$?"
	
	((PROCESS_RET)) && return $DOES_NOT_EXIST
	
	return $EXIST
}

function check_protocol_name {
	# Retuns true if a protocol already exists
	# for a determined server
	# Arguments:
	# First > the server
	# Second > the protocol

	local NAME_SERVER="$1"
	local PROTOCOL="$2"

	awk '
	{
		if (nameserver == $1)
		{
			in_range=1
		}

		if (in_range)
		{
			split($1,tmp_split,"-")

			if ($1 == "}")
			{
				exit 1
			}
			else if (tmp_split[1] == protocol)
			{
				exit 0
			}
		}
	}
	' \
	nameserver="$NAME_SERVER" \
	protocol="$PROTOCOl" \
	"$FILE_SERVER"
	
	declare -i PROCESS_RET=$?

	((PROCESS_RET)) && return 1

	return 0
}

function check_protocol_port {
	# Retuns true if a port already exists
	# for a determined server
	# Arguments:
	# First > the server
	# Second > the port


	local NAMESERVER="$1"
	declare -i PORT=$2
	local INT_PROTOCOL="$3"

	if ! check_port_limit "$PORT"
	then
		CHECK_PROTOCOL_PORT_ERROR="$CHECK_PORT_LIMIT_ERROR"
		unset CHECK_PORT_LIMIT_ERROR
		return 1
	fi
	
	awk '
	{
		if (nameserver == $1)
		{
			in_range=1
		}

		if (in_range)
		{
			split($1,tmp_split,"-")
			if ($1 == "}")
			{
				exit 1
			}
			else if ((tmp_split[2] == port) && (tmp_split[3] == int_protocol))
			{
				exit 0
			}
		}
	}
	' \
	nameserver="$NAMESERVER" \
	port="$PORT" \
	int_protocol="$INT_PROTOCOL" \
	"$FILE_SERVER"
	
	declare -i PROCESS_RET=$?

	((PROCESS_RET)) && return 1

	return 0

}

function add_protocol {
	# Add a protocol to the determined server
	# Arguments:
	# First > the server
	# Second > the protocol
	# third > the port
	# fourth > internet protocol
	# Fifth > ssh connection type - with password 0 or public key 1
	# Sixth > User to log in

	local NAMESERVER=$1
	local PROTOCOl=$2
	declare -i PORT=$3
	local INT_PROTOCOL=$4
	local SSH_TYPE="$5"
	local USER_NAME="$6"
	
	if check_protocol_name "$NAMESERVER" "$PROTOCOl"
	then
		ADD_PROTOCOL_ERROR="There's already a protocol with the name $PROTOCOL"
		return 1
	elif check_protocol_port "$NAMESERVER" "$PORT" "$INT_PROTOCOL"
	then
		ADD_PROTOCOL_ERROR="There's already a protocol with the port $PORT"
		return 1
	elif ! verify_server_in_file "$NAMESERVER"
	then
		ADD_PROTOCOL_ERROR="Server $NAMESERVER does not exist!"
		return 1
	elif ! space_finder "$PROTOCOL"
	then
		ADD_PROTOCOL_ERROR="$SPACE_FINDER_ERROR"
		return 1
	elif ! internet_protocol_check "$INT_PROTOCOL"
	then
		ADD_PROTOCOL_ERROR="The internet protocol $INT_PROTOCOL does not exist!"
		return 1
	elif ! check_port_limit "$PORT"
	then
		ADD_PROTOCOL_ERROR="$CHECK_PORT_LIMIT_ERROR"
		unset CHECK_PORT_LIMIT_ERROR
		return 1
	fi

	awk '
	{
		print $0
		if ((ssh_auth_type) && (ssh_user))
		{
			ssh_separator = "_"
		}

		if (nameserver == $1)
		{
			print protocol "-" port "-" int_prot " " ssh_auth_type ssh_separator ssh_user
			ok = 1
		}
	}

	END {
		if  (! ok)
		{
			exit 1
		}
		else
		{
			exit 0
		}
	}
	' \
	nameserver="$NAMESERVER" \
	protocol="$PROTOCOl" \
	port="$PORT"  \
	int_prot="$INT_PROTOCOL" \
	ssh_auth_type="$SSH_TYPE" \
	ssh_user="$USER_NAME" \
	"$FILE_SERVER" > "$TMP_INFO"

	declare -i RETURN_VAL=$?

	if ((RETURN_VAL))
	then
		ADD_PROTOCOL_ERROR="Impossible to add the protocol!"
		return 1
	fi

	rm "$FILE_SERVER"
	mv "$TMP_INFO" "$FILE_SERVER"

	return 0
}

function check_port_limit {
	declare -i PORT=$1

	if ((! PORT))
	then
		CHECK_PORT_LIMIT_ERROR="Unkown port was passed."
		return 1
	elif ((PORT > 65535))
	then
		CHECK_PORT_LIMIT_ERROR="Port is bigger than 65535 (Port limitation!)"
		return 1
	fi

	return 0
}

function modify_protocol {
	# Change a protocol info for a determined server
	# it only supports changes such as name or port and internet protocol
	# Arguments:
	# First > the server
	# Second > the protocol
	# Third > the port
	# Fourth > the internet protocol
	# Fifth > status change (name - 0 or port - 1)
	# Sixth > SSH special - Authentication type Password or Public key authentication
	# Seventh > SSH User
	
	local NAMESERVER="$1"
	local PROTOCOl="$2"
	declare -i PORT=$3
	local INT_PROTOCOL="$4"
	declare -i STATUS_CHANGE=$5
	declare -i SSH_TYPE=$6
	local USER_NAME=$7
	
	if ! verify_server_in_file "$NAMESERVER"
	then
		CHANGE_PROTOCOL_ERROR="Server $NAMESERVER does not exist!"
		return 1
	elif ! internet_protocol_check "$INT_PROTOCOL"
	then
		CHANGE_PROTOCOL_ERROR="The internet protocol $INT_PROTOCOL does not exist!"
		return 1
	elif ! check_port_limit "$PORT"
	then
		CHANGE_PROTOCOL_ERROR="$CHECK_PORT_LIMIT_ERROR"
		unset CHECK_PORT_LIMIT_ERROR
		return 1
	fi
	
	if ((STATUS_CHANGE == 0))
	then
		if check_protocol_name "$NAMESERVER" "$PROTOCOL"
		then
			CHANGE_PROTOCOL_ERROR="This protocol $PROTOCOL already exists!"
			return 1
		elif ! space_finder "$PROTOCOL"
		then
			CHANGE_PROTOCOL_ERROR="$SPACE_FINDER_ERROR"
			return 1
		fi

	else
		if check_protocol_port "$NAMESERVER" "$PORT" "$INT_PROTOCOL"
		then
			CHANGE_PROTOCOL_ERROR="This port $PORT already exists within other protocol!"
			return 1
		fi
	fi

	awk '
	{
		if (nameserver == $1)
		{
			in_range=1
		}

		if (in_range)
		{
			split($1,tmp_split,"-")
			if ($1 == "}")
			{
				in_range = 0
				print $0
			}
			else if ((tmp_split[1] == protocol) ||(tmp_split[2] == port))
			{
				print protocol "-" port "-" int_prot " " ssh_auth_type "_" ssh_user
				okage = 1
			}
			else
			{
				print $0
			}
		}
		else
		{
			print $0
		}
	}
	
	END {
		if (! okage)
		{
			exit 1
		}
	}

	' \
	nameserver="$NAMESERVER" \
	protocol="$PROTOCOl" \
	port="$PORT" \
	int_prot="$INT_PROTOCOL" \
	ssh_auth_type="$SSH_TYPE" \
	ssh_user="$USERNAME" \
	"$FILE_SERVER" > "/tmp/file.tmp"

	declare -i RETURN_VAL=$?

	if ((RETURN_VAL))
	then
		CHANGE_PROTOCOL_ERROR="Impossible to modify the protocol!"
		return 1
	fi

	rm "$FILE_SERVER"
	mv "/tmp/file.tmp" "$FILE_SERVER"
	
	return 0
}

function remove_protocol {
	# Remove a protocol from a determined server
	# Arguments:
	# First > the server
	# Second > the protocol

	local NAME_SERVER="$1"
	local PROTOCOL="$2"

	if [ -z "$PROTOCOL" ]
	then
		REMOVE_PROTOCOL_ERROR="No protocol was passed!"
		return 1
	elif ! verify_server_in_file "$NAME_SERVER"
	then
		REMOVE_PROTOCOL_ERROR="Server $NAME_SERVER does not exist!"
		return 1
	fi

	awk '
	{
		if (nameserver == $1)
		{
			in_range=1
		}

		if (in_range)
		{
			split($1, tmp_split, "-")
			if ($1 == "}")
			{
				in_range = 0
				print $0
			}
			else if (tmp_split[1] == protocol)
			{
				ok = 1
			}
			else
			{
				print $0
			}
		}
		else
		{
			print $0
		}
	}
	
	END {
		if (ok != 1)
		{
			exit 1
		}
	}
	' \
	nameserver="$NAME_SERVER" \
	protocol="$PROTOCOL" \
	"$FILE_SERVER" > "$TMP_INFO"
	
	declare -i RET_VAL=$?

	if ((RET_VAL))
	then
		REMOVE_PROTOCOL_ERROR="Couldn't delete the protocol!"
		return 1
	fi

	rm "$FILE_SERVER"
	mv "$TMP_INFO" "$FILE_SERVER"

	return 0
}

function remove_server {
	# Remove a server from the file list
	# and
	# all the protocols within its range
	# Arguments:
	# First > the server

	local NAMESERVER="$1"
	
	if ! verify_server_in_file "$NAMESERVER"
	then
		REMOVE_SERVER_ERROR="Server $NAMESERVER does not exist!"
		return 1
	fi

	local LINE_PICK_OCURRENCE=$(grep -n "^$NAMESERVER" "$FILE_SERVER" | cut -d ":" -f 1)

	if [ -z "$LINE_PICK_OCURRENCE" ]
	then
		LINE_PICK_OCURRENCE=$(grep -n ".* | $NAMESERVER {" "$FILE_SERVER" | cut -d ":" -f 1)
	fi

	if [ -z "$LINE_PICK_OCURRENCE" ]
	then
		REMOVE_SERVER_ERROR="Nothing was found!"
		return 1
	fi

	local LAST_PICK_OCURRENCE=$(grep -n "^}$" "$FILE_SERVER" | cut -d ":" -f 1)

	if [ -z "$LAST_PICK_OCURRENCE" ]
	then
		REMOVE_SERVER_ERROR="Nothing was found!"
		return 1
	fi

	local LAST_LINES
	for LAST_LINES in $LAST_PICK_OCURRENCE
	do
		if ((LAST_LINES > LINE_PICK_OCURRENCE))
		then
			LAST_PICK_OCURRENCE="$LAST_LINES"
			break
		fi
	done
	
	sed -i "${LINE_PICK_OCURRENCE},${LAST_PICK_OCURRENCE}d" "$FILE_SERVER"

	return 0
}

function internet_protocol_check {
	local INT_PROTOCOL="$1"
	
	case "$INT_PROTOCOL" in
		"TCP"|"UDP")
			return 0
			;;
		*)
			return 1
	esac
}

function add_server {
	# Add a server to the file
	# Arguments:
	# First > the server name
	# Second > the server ip

	local NAMESERVER=$1
	local IPSERVER=$2
	
	if ! check_ip "$IPSERVER"
	then
		ADD_SERVER_ERROR="$CHECK_IP_ERROR"
		unset CHECK_IP_ERROR
		return 1
	fi

	if verify_server_in_file "$NAMESERVER"
	then
		ADD_SERVER_ERROR="There's already a server called $NAMESERVER"
		return 1
	elif verify_server_in_file "$IPSERVER"
	then
		ADD_SERVER_ERROR="There's already the ip $IPSERVER !"
		return 1
	elif ! space_finder "$NAMESERVER"
	then
		ADD_SERVER_ERROR="$SPACE_FINDER_ERROR"
		return 1
	fi

	awk '
	{
		print $0
	}
	END {
		print nameserver " | " ipserver " {\n}"
	}
	' nameserver="$NAMESERVER" \
	  ipserver="$IPSERVER" \
	  "$FILE_SERVER" > "/tmp/file.tmp"

	rm "$FILE_SERVER"
	mv "/tmp/file.tmp" "$FILE_SERVER"

	return 0
}

function change_server {
	# Change the server info. change the name or the IP of the server
	# Arguments:
	# First > the server name
	# Second > the server ip
	# Third > the change mode, such as IP(0) or name(1)
	# default is 0

	local NAMESERVER="$1"
	local SERVER_IP="$2"
	declare -i STATUS_CHANGE=$3

	if ((STATUS_CHANGE == 1))
	then
		if verify_server_in_file "$NAMESERVER"
		then
			CHANGE_SERVER_ERROR="This server name $NAMESERVER is already being used!"
			return 1
		fi

	else
		if ! check_ip "$SERVER_IP"
		then
			CHANGE_SERVER_ERROR="$CHECK_IP_ERROR"
			unset CHECK_IP_ERROR
			return 1
		elif verify_server_in_file "$SERVER_IP"
		then
			CHANGE_SERVER_ERROR="This server ip $SERVER_IP is already being used!"
			return 1
		elif ! space_finder "$NAMESERVER"
		then
			CHANGE_SERVER_ERROR="SPACE_FINDER_ERROR"
			return 1
		fi
	fi

	awk '
	{
		if ((nameserver == $1) || (server_ip == $3))
		{
			print nameserver " | " server_ip " {"
			ok = 1
		}
		else
		{
			print $0
		}
	}
	
	END {
		if (! ok)
		{
			exit 1
		}
	}
	' \
	nameserver="$NAMESERVER" \
	server_ip="$SERVER_IP" \
	"$FILE_SERVER" > "/tmp/file.tmp"

	declare -i RETURN_VAL=$?

	if ((RETURN_VAL))
	then
		CHANGE_SERVER_ERROR="Impossible to modify the protocol!"
		return 1
	fi

	rm "$FILE_SERVER"
	mv "/tmp/file.tmp" "$FILE_SERVER"

	return 0
}

function pick_protocol_info {
	local NAME_SERVER="$1"
	local PROTOCOL="$2"

	
	PICK_PROTOCOL_INFO="$(awk '
	{
		if (nameserver == $1)
		{
			in_range=1
		}

		if (in_range)
		{
			split($1,tmp_split,"-")
			if ($1 == "}")
			{
				exit 1
			}
			else if (tmp_split[1] == protocol)
			{
				print tmp_split[1]
				print tmp_split[2]
				print tmp_split[3]

				exit 0
			}
		}
	}
	' \
	nameserver="$NAME_SERVER" \
	protocol="$PROTOCOL" \
	"$FILE_SERVER"
	)"

	declare -i RET_VAL=$?

	if ((RET_VAL))
	then
		PICK_PROTOCOL_INFO_ERROR="Something went wrong..."
		return 1
	fi
	
	return 0
}

function ssh_type {
	local NAME_SERVER="$1"

	if ! list_all_protocols "$NAME_SERVER"
	then
		SSH_TYPE_ERROR="$LIST_ALL_PROTOCOLS_ERROR"
		return 1
	fi
	
	local PROTOCOL_INFO
	for PROTOCOL_INFO in $LIST_ALL_PROTOCOLS_VAR
	do
		if [ "$PROTOCOL_INFO" = "SSH" ]	
		then
			local FOUND="ok"
		elif ! [ -z "$FOUND" ]
		then
			if [ -z "$SSH_TYPE_VAL" ]
			then
				declare -i COUNT=0
				SSH_TYPE_VAL="$PROTOCOL_INFO"
			else
				((++COUNT))

				SSH_TYPE_VAL="$SSH_TYPE_VAL $PROTOCOL_INFO"

				if ((COUNT == 4))
				then
					break
				fi
			fi
		fi
	done

	if [ -z "$FOUND" ]
	then
		SSH_TYPE_ERROR="No ssh protocol was found in $SERVER_NAME"
		return 1
	fi


	return 0
}
