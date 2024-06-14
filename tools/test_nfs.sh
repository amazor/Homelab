#!/bin/bash

# Check if the correct number of arguments are passed
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <NFS_Server_IP> <NFS_Share_Path> <Mount_Point> [Sizes...]"
    exit 1
fi

# Assign command line arguments to variables
NFS_SERVER_IP=$1
NFS_SHARE_PATH=$2
MOUNT_POINT=$3
shift 3 # Shift the first three parameters out, leaving only sizes if provided

# Default sizes to test if none are provided
DEFAULT_SIZES=(8192 16384 32768 65536)
SIZES=("${@:-${DEFAULT_SIZES[@]}}") # Use provided sizes or defaults if none

# Results file
RESULTS_FILE="nfs_performance_results.txt"
echo "rsize, wsize, read speed (MB/s), write speed (MB/s), read time (s), write time (s)" > $RESULTS_FILE

# Ensure the mount point is available
mkdir -p $MOUNT_POINT

# Accumulators for averages
total_write_time=0
total_read_time=0
count=0

# Best parameters tracking
best_write_time=999999
best_read_time=999999
best_params_write=""
best_params_read=""

# Function to mount NFS with specific rsize and wsize
mount_nfs() {
    sudo umount $MOUNT_POINT 2>/dev/null
    sudo mount -t nfs -o rsize=$1,wsize=$2 $NFS_SERVER_IP:$NFS_SHARE_PATH $MOUNT_POINT
}

# Function to run write test
test_write_performance() {
    SECONDS=0
    sync; echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null
    WRITE_OUTPUT=$(dd if=/dev/zero of=$MOUNT_POINT/testfile bs=1M count=1024 oflag=direct 2>&1)
    WRITE_RESULT=$?
    WRITE_TIME=$SECONDS
    if [ $WRITE_RESULT -eq 0 ]; then
        WRITE_SPEED=$(echo "$WRITE_OUTPUT" | awk '/copied/ { print $(NF-1) }')
    else
        WRITE_SPEED="error"
    fi
    echo $WRITE_SPEED $WRITE_TIME
}

# Function to run read test
test_read_performance() {
    SECONDS=0
    READ_OUTPUT=$(dd if=$MOUNT_POINT/testfile of=/dev/null bs=1M 2>&1)
    READ_RESULT=$?
    READ_TIME=$SECONDS
    if [ $READ_RESULT -eq 0 ]; then
        READ_SPEED=$(echo "$READ_OUTPUT" | awk '/copied/ { print $(NF-1) }')
    else
        READ_SPEED="error"
    fi
    echo $READ_SPEED $READ_TIME
}

# Print header for the results
printf "%-6s %-6s %-20s %-20s %-15s %-15s\n" "rsize" "wsize" "Read Speed (MB/s)" "Write Speed (MB/s)" "Read Time (s)" "Write Time (s)"
echo "-----------------------------------------------------------------------------------------"

# Test different rsize and wsize settings
for r in "${SIZES[@]}"; do
    for w in "${SIZES[@]}"; do
        echo -n "Testing rsize=$r, wsize=$w..." 1>&2
        mount_nfs $r $w
        WRITE_RESULTS=($(test_write_performance))
        READ_RESULTS=($(test_read_performance))
        echo -ne "\r\033[K"  # Clear the testing status line
        printf "%-6s %-6s %-20s %-20s %-15s %-15s\n" "$r" "$w" "${READ_RESULTS[0]}" "${WRITE_RESULTS[0]}" "${READ_RESULTS[1]}" "${WRITE_RESULTS[1]}"
        echo "$r, $w, ${READ_RESULTS[0]}, ${WRITE_RESULTS[0]}, ${READ_RESULTS[1]}, ${WRITE_RESULTS[1]}" >> $RESULTS_FILE

        # Accumulate times
        total_write_time=$((total_write_time + WRITE_RESULTS[1]))
        total_read_time=$((total_read_time + READ_RESULTS[1]))
        count=$((count + 1))

        # Track best parameters
        if [[ "${WRITE_RESULTS[1]}" -lt "$best_write_time" ]]; then
            best_write_time=${WRITE_RESULTS[1]}
            best_params_write="rsize=$r, wsize=$w"
        fi
        if [[ "${READ_RESULTS[1]}" -lt "$best_read_time" ]]; then
            best_read_time=${READ_RESULTS[1]}
            best_params_read="rsize=$r, wsize=$w"
        fi
    done
done

# Display averages and best parameters
average_write_time=$((total_write_time / count))
average_read_time=$((total_read_time / count))
echo -e "\nAverage Read Time: $average_read_time s"
echo "Average Write Time: $average_write_time s"
echo "Best Read Parameters: $best_params_read (Time: $best_read_time s)"
echo "Best Write Parameters: $best_params_write (Time: $best_write_time s)"

# Clean up
sudo umount $MOUNT_POINT
echo "Tests completed. Detailed results are logged in $RESULTS_FILE."
