#! /bin/bash

IP_HANDLER_VAR_FILENAME="ip_list.conf"
IP_HANDLER_VAR_FILENAME_TMP="ip_list.conf.tmp"
IP_HANDLER_VAR_FOLDER=$(dirname $0)
IP_HANDLER_VAR_RESULTS="ip_result.chk"

function duplication {
	# Returns true if there's an IP on the file already

	local ERROR=1
	local OK=0
	local IP=$1

	if awk '
	{
	if (desired == $1)
	{
		exit 1
	}
	}
	' desired=$IP "$IP_HANDLER_VAR_FOLDER/$IP_HANDLER_VAR_FILENAME"
	then
		return $ERROR
	else
		return $OK
	fi

}

function check_ip {
	# Returns true if all the IP is actually an IP as well as a network
	# It does not handle IPV6 and support it

	local ERROR=1
	local OK=0

	local -r IP=$1
	
	if  [ -z "$IP" ]
	then
		CHECK_IP_ERROR="There is no IP at all..."
		return $ERROR
	fi

	local IFS="."

	local IP_CHUNKAGE=4
	local IP_CHUNKS=0
	
	# Name a few deault values

	local NETWORK_IP=0
	local MAX_BYTE=255
	local MIN_BYTE=0
	local MAX_CHUNKAGE=4
	local IP_REGEX="^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}"

	local CHUNK	
	for CHUNK in $IP
	do
		((++IP_CHUNKS))
		
		if echo $CHUNK | grep -q "$IP_REGEX"
		then
			CHECK_IP_ERROR="The IP passed don't have only intergers"
			return $ERROR
		fi

		if ((CHUNK > MAX_BYTE || CHUNK < MIN_BYTE))
		then
			CHECK_IP_ERROR="The IP chunk localized at the $IP_CHUNKS of the $IP"
			return $ERROR
		fi
	done
	
	if ((IP_CHUNKS > MAX_CHUNKAGE))
	then
		CHECK_IP_ERROR="The IP have more than 4 chunks"
		return $ERROR
	elif ((IP_CHUNKS < MAX_CHUNKAGE))
	then
		CHECK_IP_ERROR="The IP have less than 4 chunks"
		return $ERROR
	else
		if ((IP_CHUNKS == IP_CHUNKAGE))
		then
			if ((CHUNK == NETWORK_IP))
			then
				CHECK_IP_ERROR="The IP passed is a network!"
				return $ERROR
			fi
		fi
	fi
	return $OK
}

function handle_ip {
	# Add the IP to the file
	
	local ERROR=1
	local OK=0

	local -r IP=$1

	if check_ip $IP
	then
		touch "$IP_HANDLER_VAR_FOLDER/$IP_HANDLER_VAR_FILENAME"
		
		if duplication "$IP"
		then
			HANDLE_IP_ERROR="The network IP $IP is already on the file!"
			return $ERROR
		else
			echo "$IP" >> "$IP_HANDLER_VAR_FOLDER/$IP_HANDLER_VAR_FILENAME"
		fi
		
		declare -i local RANGE=$2
		
		if ((RANGE))
		then
			if ! define_range $IP $RANGE
			then
				echo $DEFINE_RANGE_ERROR
				unset -v DEFINE_RANGE_ERROR
				return $ERROR
			fi
		fi

		return $OK
	else
		echo $CHECK_IP_ERROR
		unset -v CHECK_IP_ERROR

		return $ERROR
	fi
}

function define_range {
	# It defines a range to the IP

	local ERROR=1
	local OK=0

	local OPTION=$1
	
	if check_ip $OPTION
	then
		local WHICH_IP=$OPTION
		declare -i local RANGE_IP=$2
		OPTION="DEFAULT"
	else
		local -r OPTIONS=("ALL" "EXCLUDE" "DEFAULT")
		
		local TMP_OPTION
		local TRUTH=false
		for TMP_OPTION in ${OPTIONS[*]}
		do
			if [ "$TMP_OPTION" = "$OPTION" ]
			then
				TRUTH=true
				break
			fi
		done
		
		if ! $TRUTH
		then
			DEFINE_RANGE_ERROR="Uknown option!"
			return $ERROR
		fi

		local WHICH_IP=$2

		declare -i local RANGE_IP=$3
	fi

	if ! check_ip $WHICH_IP
	then
		if ! [ "$OPTION" = "${OPTIONS[0]}" ]
		then
			echo "$CHECK_IP_ERROR"
			unset CHECK_IP_ERROR
			return $ERROR
		else
			RANGE_IP="$WHICH_IP"
			WHICH_IP="NULL"
		fi
	fi

	if ((RANGE_IP == 0))
	then
		DEFINE_RANGE_ERROR="Wrong input. Can't be 0 or string"
		return $ERROR
	fi

	if ((RANGE_IP > 254))
	then
		DEFINE_RANGE_ERROR="Too many IPs!"
		return $ERROR
	fi
	
	if ! duplication $WHICH_IP
	then
		DEFINE_RANGE_ERROR="Network IP $WHICH_IP not available. BUGGISH THING!"
		return $ERROR
	fi
	
	awk '
	{
	
	if (option == "DEFAULT")
	{
		if (which_ip == $1)
		{
			print $1 "\t" range_ip
		}
		else
		{
			print $1 "\t" $2
		}

	}
	else if (option == "ALL")
	{
		print $1 "\t" range_ip
	}
	
	else if (option == "EXCLUDE")
	{
		if (which_ip != $1)
		{
			print $1 "\t" range_ip
		}
		else
		{
			print $1 "\t" $2
		}
	}

	else
	{
		exit 1
	}

	}
	' option="$OPTION" which_ip="$WHICH_IP" range_ip="$RANGE_IP" "$IP_HANDLER_VAR_FOLDER/$IP_HANDLER_VAR_FILENAME" > "$IP_HANDLER_VAR_FOLDER/$IP_HANDLER_VAR_FILENAME_TMP"

	cat "$IP_HANDLER_VAR_FOLDER/$IP_HANDLER_VAR_FILENAME_TMP" > "$IP_HANDLER_VAR_FOLDER/$IP_HANDLER_VAR_FILENAME"

	rm "$IP_HANDLER_VAR_FOLDER/$IP_HANDLER_VAR_FILENAME_TMP"

	return $OK
}

function remove_ip {
	local IP=$1
	local ERROR=1
	local OK=0
	local IP_UNCONFLICTED_REGEX=$(echo $IP | sed 's/\./\\\./g')
	

	if check_ip $IP
	then
		if ! duplication $IP
		then
			REMOVE_IP_ERROR="There's no $IP IP on the file"
			return $ERROR
		fi
	else
		REMOVE_IP_ERROR="The $IP is not a valid IP"
		return $ERROR
	fi

	# I know, this does indeed look strange
	# But, when using a variable rather than the command substitution it returns 1
	# and deletes the entire file :(
	if echo "$(cat "$IP_HANDLER_VAR_FOLDER/$IP_HANDLER_VAR_FILENAME" | grep -v $IP_UNCONFLICTED_REGEX)" > "$IP_HANDLER_VAR_FOLDER/$IP_HANDLER_VAR_FILENAME"
	then
		return $OK
	else
		REMOVE_IP_ERROR="Something went wrong to modify the file"
		return $ERROR
	fi
}

function test_ip {
	# Test all IPs or a desired one with ping
	# and writes on the file designed for the results

	local IP=$1
	
	if ! [ -z $IP ]
	then
		if check_ip $IP
		then
			declare -i local DESIRED=0
		else
			TEST_IP_ERROR=$CHECK_IP_ERROR
			unset -v CHECK_IP_ERROR
			declare -i local DESIRED=1
			return 1
		fi
	else
		declare -i local DESIRED=1
	fi
			

	
	awk '
	    BEGIN {
	    	print "BEGIN TEST!"
	    }
	
    	    function test_and_redirect(ip_net) {
		    print "Starting network " ip_net
		    split(ip_net, ip_sec, ".")
		    if (length($2) == 0)
		    {
			    print "The network IP " ip_net " does not have a range. INSERT ONE!"
			    return 1
		    }
		    for (rg_ip=1;rg_ip <= $2; ++rg_ip)
		    {
			ip = ip_sec[1] "." ip_sec[2] "." ip_sec[3] "." rg_ip
			if (system("ping -c1 -q " ip " > /dev/null 2>&1") == 0)
			{
				print ip " OK"
			}
			else
			{
				print ip " ERROR"
			}
	    	    }
	    	    print "End of network " ip_net
	    }

	    {
		    if (desired == 0)
	            {
			if (ip_sin == $1)
			{
		    		test_and_redirect(ip_sin)
				exit 0
			}
			else
			{
				next
			}
		    }
	    	    else
		    {
	         	   test_and_redirect($1)
	    	    }
	    }
    	    END {
	    	print "END TEST"
	    }' desired="$DESIRED" ip_sin="$IP" "$IP_HANDLER_VAR_FOLDER/$IP_HANDLER_VAR_FILENAME" > "$IP_HANDLER_VAR_FOLDER/$IP_HANDLER_VAR_RESULTS"
}

# Modify this function for your use!
function test_ {

	echo "Modify the $FUNCNAME to use this script"
	# This adds the ip
	# It's possible to add or change the range with this
	#handle_ip 192.168.5.0
	#handle_ip 192.164.2.0
	#handle_ip 145.124.10.0
	
	# This remove the IPs
	#remove_ip 192.168.5.0
	#remove_ip 192.164.2.0
	#remove_ip 145.124.10.0

	# Define the range of an IP
	# This is the possibles options EXCLUDE and ALL
	# If there's no option as the first argument
	# the function will use the default, to modify only that one
	# define_range EXCLUDE 192.168.5.0 100
	
	# This test all IPs, if one isn't given
	# test_ip
	echo $DEFINE_RANGE_ERROR
}
