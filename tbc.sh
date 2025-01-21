#!/bin/bash

NIC_PORT="${NIC_PORT:-ens4f0}"
NIC_PORT_SLAVE="${NIC_PORT_SLAVE:-ens5f0}"
UPSTREAM_PORT="${UPSTREAM_PORT:-ens4f0}"

# Use this command:
# sudo podman run --privileged --network=host --rm quay.io/vgrinber/tools:dpll dpll-cli dumpPins |jq -r '. | select(.clockId == "0x507c6fffff1fb218") | select(.boardLabel |test("GNSS|SDP")) | "\(.boardLabel)\t\(.id)"'


GNSS_ID="${GNSS_ID:-23}"
SDP23_ID="${SDP23_ID:-29}"
SDP21_ID="${SDP21_ID:-28}"
SDP22_ID="${SDP22_ID:-17}"
SDP20_ID="${SDP20_ID:-18}"

# Functions

# prints command to disable the input by ID passed as $1
mk_disable_input_cmd () {
        id=$1
        JSON_STR=$(jq -n --arg id "$id" \
          '{"id": $id,"parent-device":[{"parent-id":2,"prio":255,"state":"disconnected"},{"parent-id":3,"prio":255,"state":"disconnected"}]}')
	CMD="sudo podman run --privileged --network=host --rm \
		quay.io/vgrinber/tools:dpll python3 cli.py --spec /linux/Documentation/netlink/specs/dpll.yaml --do pin-set --json '${JSON_STR}'"
	echo $CMD
}

# prints command to disable the output by ID passed as $1
mk_disable_output_cmd () {
        id=$1
        JSON_STR=$(jq -n --arg id "$id" \
          '{"id": $id,"parent-device":[{"parent-id":2,"state":"disconnected"},{"parent-id":3,"state":"disconnected"}]}')
	CMD="sudo podman run --privileged --network=host --rm \
		quay.io/vgrinber/tools:dpll python3 cli.py --spec /linux/Documentation/netlink/specs/dpll.yaml --do pin-set --json '${JSON_STR}'"
	echo $CMD
}

# prints command to enable the input by ID passed as $1
mk_enable_input_cmd () {
        id=$1
        JSON_STR=$(jq -n --arg id "$id" \
          '{"id": $id,"parent-device":[{"parent-id":2,"prio":0,"state":"selectable"},{"parent-id":3,"prio":0,"state":"selectable"}]}')
	CMD="sudo podman run --privileged --network=host --rm \
		quay.io/vgrinber/tools:dpll python3 cli.py --spec /linux/Documentation/netlink/specs/dpll.yaml --do pin-set --json '${JSON_STR}'"
	echo $CMD
}

# prints command to enable the output by ID passed as $1
mk_enable_output_cmd () {
        id=$1
        JSON_STR=$(jq -n --arg id "$id" \
          '{"id": $id,"parent-device":[{"parent-id":2,"state":"connected"},{"parent-id":3,"state":"connected"}]}')
	CMD="sudo podman run --privileged --network=host --rm \
		quay.io/vgrinber/tools:dpll python3 cli.py --spec /linux/Documentation/netlink/specs/dpll.yaml --do pin-set --json '${JSON_STR}'"
	echo $CMD
}
# Runs command given as a string in $1
run_command () {
   	local CMD=$1
	eval $CMD
        rv=$?
        if [ $rv -ne 0 ]; then
		echo "Error"
	fi
}



enable_mac_1_pps () {
	 sudo bash -c "echo 2 0 0 1 0 > /sys/class/net/$NIC_PORT/device/ptp/ptp*/period"
}

enable_sma_1_pps () {
	 sudo bash -c "echo 2 1 > /sys/class/net/$NIC_PORT/device/ptp/*/pins/SMA1"
	 sudo bash -c "echo 1 1 > /sys/class/net/$NIC_PORT_SLAVE/device/ptp/*/pins/SMA1"
	# for measurements:
	 sudo bash -c "echo 2 2 > /sys/class/net/$NIC_PORT_SLAVE/device/ptp/*/pins/SMA2"
}

get_ts2phc_pid () {
	pidstr=$(ps -ef |grep ts2phc |grep openshift)
	arr=($pidstr)
	echo ${arr[1]}		
}

start_ts2phc () {
	nohup oc -n openshift-ptp -c linuxptp-daemon-container exec  ds/linuxptp-daemon  -- /bin/chrt -f 10 /usr/sbin/ts2phc -f /var/run/ts2phc.0.config  -s generic &
}

kill_ts2phc () {
	pid=$(get_ts2phc_pid)
	if [ ! -z "${pid}" ]; then 
		sudo kill -9 $pid
	fi
}


init () {
	
        enable_sma_1_pps
	# Enable 1PPS from E810 in the driver
	enable_mac_1_pps &> /dev/null

	# Disable all inputs
	for i in "$GNSS_ID" "$SDP22_ID" "$SDP20_ID"; do
		cmd=$(mk_disable_input_cmd $i)
		res=$(run_command "$cmd")
        	if [[ "$res" != "None" ]]; then
			echo "Failed to run command: $cmd"
			return 1
        	fi
	done
	
	# Disable all outputs
	for i in "$SDP21_ID" "$SDP23_ID"; do
		cmd=$(mk_disable_output_cmd $i)
		res=$(run_command "$cmd")
        	if [[ "$res" != "None" ]]; then
			echo "Failed to run command: $cmd"
			return 1
        	fi
	done
}


normal () {

	#kill_ts2phc

	sudo ip link set $UPSTREAM_PORT up

	CMD=$(mk_enable_input_cmd $SDP22_ID)
	echo $CMD
        res=$(run_command "$CMD")
        if [[ "$res" != "None" ]]; then
        	echo "Failed to run command: $cmd"
                return 1
        fi
	CMD=$(mk_enable_input_cmd $SDP20_ID)
	echo $CMD
        res=$(run_command "$CMD")
        if [[ "$res" != "None" ]]; then
        	echo "Failed to run command: $cmd"
                return 1
        fi
	cmd=$(mk_disable_output_cmd $SDP23_ID)
        echo $cmd
	res=$(run_command "$cmd")
        if [[ "$res" != "None" ]]; then
                echo "Failed to run command: $cmd"
                return 1
        fi
}


hold () {
	sudo ip link set $UPSTREAM_PORT down
	
        cmd=$(mk_disable_input_cmd $SDP22_ID)
	echo $cmd
        res=$(run_command "$cmd")
        if [[ "$res" != "None" ]]; then
                echo "Failed to run command: $cmd"
        	return 1
        fi
        cmd=$(mk_disable_input_cmd $SDP20_ID)
	echo $cmd
        res=$(run_command "$cmd")
        if [[ "$res" != "None" ]]; then
                echo "Failed to run command: $cmd"
        	return 1
        fi
       
	cmd=$(mk_enable_output_cmd $SDP23_ID)
        echo $cmd
	res=$(run_command "$cmd")
        if [[ "$res" != "None" ]]; then
                echo "Failed to run command: $cmd"
                return 1
        fi
	
	 # start_ts2phc
}
