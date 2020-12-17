# A simple ip_tester
if [ -z "$TMP_INFO" ]
then
	echo "The variable TMP_INFO is not defined!"
	exit 1
fi


function test_IP {
	declare -i TIMES=1
	local IP=$1
	
	if ! check_ip "$IP"
	then
		TEST_SERVER_ERROR="This $IP is not an IP!"
		return 1
	fi

	ping -c $TIMES $IP > /dev/null 2>&1

	return $?
}

