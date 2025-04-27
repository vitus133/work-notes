#!/bin/bash

TIME_RECEIVER_NIC="${TIME_RECEIVER_NIC:-ens4f0}"
PPS_FOLLOWER_NIC="${PPS_FOLLOWER_NIC:-ens5f0}"
UPSTREAM_PORT="${UPSTREAM_PORT:-ens4f0}"

# Time receiver NIC pin IDs
GNSS_ID="${GNSS_ID:-23}"
SDP23_ID="${SDP23_ID:-29}"
SDP21_ID="${SDP21_ID:-28}"
SDP22_ID="${SDP22_ID:-17}"
SDP20_ID="${SDP20_ID:-18}"

# Time receiver NIC pin parent IDs
PPID_EEC=2
PPID_PPS=3

# Functions
# prints command to disable the input by ID passed as $1
mk_disable_input_cmd () {
        id=$1
        JSON_STR=$(jq -n --arg id "$id" --arg PPID_EEC "$PPID_EEC" --arg PPID_PPS "$PPID_PPS" \
          '{"id": $id,"parent-device":[{"parent-id":$PPID_EEC,"prio":255,"state":"disconnected"},{"parent-id":$PPID_PPS,"prio":255,"state":"disconnected"}]}')
    CMD="sudo podman run --privileged --network=host --rm \
        quay.io/vgrinber/tools:dpll python3 cli.py --spec /linux/Documentation/netlink/specs/dpll.yaml --do pin-set --json '${JSON_STR}'"
    echo $CMD
}


# prints command to disable the output by ID passed as $1
mk_disable_output_cmd () {
        id=$1
        JSON_STR=$(jq -n --arg id "$id" --arg PPID_EEC "$PPID_EEC" --arg PPID_PPS "$PPID_PPS" \
          '{"id": $id,"parent-device":[{"parent-id":$PPID_EEC,"state":"disconnected"},{"parent-id":$PPID_PPS,"state":"disconnected"}]}')
    CMD="sudo podman run --privileged --network=host --rm \
        quay.io/vgrinber/tools:dpll python3 cli.py --spec /linux/Documentation/netlink/specs/dpll.yaml --do pin-set --json '${JSON_STR}'"
    echo $CMD
}

# prints command to enable the input by ID passed as $1
mk_enable_input_cmd () {
        id=$1
        JSON_STR=$(jq -n --arg id "$id" --arg PPID_EEC "$PPID_EEC" --arg PPID_PPS "$PPID_PPS" \
          '{"id": $id,"parent-device":[{"parent-id":$PPID_EEC,"prio":0,"state":"selectable"},{"parent-id":$PPID_PPS,"prio":0,"state":"selectable"}]}')
    CMD="sudo podman run --privileged --network=host --rm \
        quay.io/vgrinber/tools:dpll python3 cli.py --spec /linux/Documentation/netlink/specs/dpll.yaml --do pin-set --json '${JSON_STR}'"
    echo $CMD
}

mk_enable_input_cmd_2 () {
        id=$1
        eec_prio=$2
        pps_prio=$3
        JSON_STR=$(jq -n --arg id "$id" --arg PPID_EEC "$PPID_EEC" --arg PPID_PPS "$PPID_PPS" --arg eec_prio "$eec_prio" --arg pps_prio "$pps_prio"\
          '{"id": $id,"parent-device":[{"parent-id":$PPID_EEC,"prio":$eec_prio,"state":"selectable"},{"parent-id":$PPID_PPS,"prio":$pps_prio,"state":"selectable"}]}')
    CMD="sudo podman run --privileged --network=host --rm \
        quay.io/vgrinber/tools:dpll python3 cli.py --spec /linux/Documentation/netlink/specs/dpll.yaml --do pin-set --json '${JSON_STR}'"
    echo $CMD
}

# prints command to enable the output by ID passed as $1
mk_enable_output_cmd () {
        id=$1
        JSON_STR=$(jq -n --arg id "$id"  --arg PPID_EEC "$PPID_EEC" --arg PPID_PPS "$PPID_PPS" \
          '{"id": $id,"parent-device":[{"parent-id":$PPID_EEC,"state":"connected"},{"parent-id":$PPID_PPS,"state":"connected"}]}')
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



enable_e810_1_pps_output () {
     sudo bash -c "echo 2 0 0 1 0 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/ptp*/period"
}

enable_sma_1_pps () {
     sudo bash -c "echo 2 1 > /sys/class/net/$TIME_RECEIVER_NIC/device/ptp/*/pins/SMA1"
     sudo bash -c "echo 1 1 > /sys/class/net/$PPS_FOLLOWER_NIC/device/ptp/*/pins/SMA1"
    # for measurements:
     sudo bash -c "echo 2 2 > /sys/class/net/$PPS_FOLLOWER_NIC/device/ptp/*/pins/SMA2"
}


init () {
    
    enable_sma_1_pps
    # Enable 1PPS from E810 in the driver
    enable_e810_1_pps_output &> /dev/null

    # Disable inputs
    for i in "$GNSS_ID" "$SDP20_ID"; do
        cmd=$(mk_disable_input_cmd $i)
        res=$(run_command "$cmd")
            if [[ "$res" != "None" ]]; then
            echo "Failed to run command: $cmd"
            return 1
            fi
    done

    # enable SDP22 PPS only
    CMD=$(mk_enable_input_cmd_2 $SDP22_ID 255 0)
    echo $CMD
        res=$(run_command "$CMD")
        if [[ "$res" != "None" ]]; then
            echo "Failed to run command: $cmd"
                return 1
        fi
    
    # Disable outputs
    for i in "$SDP21_ID"; do
        cmd=$(mk_disable_output_cmd $i)
        res=$(run_command "$cmd")
            if [[ "$res" != "None" ]]; then
            echo "Failed to run command: $cmd"
            return 1
            fi
    done
}


normal () {
    sudo ip link set $UPSTREAM_PORT up
    CMD=$(mk_enable_input_cmd_2 $SDP22_ID 255 0)
    echo $CMD
        res=$(run_command "$CMD")
        if [[ "$res" != "None" ]]; then
            echo "Failed to run command: $cmd"
                return 1
        fi
    cmd=$(mk_disable_output_cmd $SDP21_ID)
        echo $cmd
    res=$(run_command "$cmd")
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

    cmd=$(mk_enable_output_cmd $SDP23_ID)
        echo $cmd
    res=$(run_command "$cmd")
        if [[ "$res" != "None" ]]; then
                echo "Failed to run command: $cmd"
                return 1
        fi
    cmd=$(mk_enable_output_cmd $SDP21_ID)
        echo $cmd
    res=$(run_command "$cmd")
        if [[ "$res" != "None" ]]; then
                echo "Failed to run command: $cmd"
                return 1
        fi
}
