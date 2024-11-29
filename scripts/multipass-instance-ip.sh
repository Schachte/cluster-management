#!/bin/bash

# Function to get IPv4 address for a given instance name
get_instance_ip() {
    local instance_name="$1"
    local input

    # Read from stdin if available, otherwise from multipass list command
    if [ -t 0 ]; then
        input=$(multipass list)
    else
        input=$(cat)
    fi

    # Skip header line and find matching instance
    echo "$input" | awk -v name="$instance_name" '
        NR > 1 {
            if ($1 == name) {
                # Find IPv4 field by looking for pattern xxx.xxx.xxx.xxx
                for (i=1; i<=NF; i++) {
                    if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
                        print $i
                        exit 0
                    }
                }
            }
        }
    '
}

# If script is called directly (not sourced), process command line argument
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <instance-name>"
        exit 1
    fi
    get_instance_ip "$1"
fi
