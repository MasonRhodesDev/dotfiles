#!/bin/sh
set -uf

# Define variables
namespace="vpnns"
primary_network_interface=$(ip route | awk '/^default/ {print $5}')
custom_resolv_conf="/etc/netns/$namespace/resolv.conf"  # Custom resolv.conf for the namespace

# Function to wait for interface creation
wait_for_interface() {
    local interface_name="$1"
    local max_attempts=10
    local attempt=0

    # Check if interface exists
    while ! ip link show | grep -q "\<$interface_name\>"; do
        sleep 1
        attempt=$((attempt + 1))

        if [ $attempt -eq $max_attempts ]; then
            echo "Timeout: Interface $interface_name not found after $max_attempts attempts."
            exit 1
        fi
    done
}

# Function to wait for namespace creation
wait_for_namespace() {
    local namespace_name="$1"
    local max_attempts=10
    local attempt=0

    # Check if namespace exists
    while ! ip netns list | grep -q "\<$namespace_name\>"; do
        sleep 1
        attempt=$((attempt + 1))

        if [ $attempt -eq $max_attempts ]; then
            echo "Timeout: Namespace $namespace_name not found after $max_attempts attempts."
            exit 1
        fi
    done
}

# Function to wait for link creation within namespace
wait_for_link_creation() {
    local namespace_name="$1"
    local link_name="$2"
    local max_attempts=10
    local attempt=0

    # Check if link exists within namespace
    while ! ip netns exec "$namespace_name" ip link show | grep -q "\<$link_name\>"; do
        sleep 1
        attempt=$((attempt + 1))

        if [ $attempt -eq $max_attempts ]; then
            echo "Timeout: Link $link_name not found in namespace $namespace_name after $max_attempts attempts."
            exit 1
        fi
    done
}

# Function to get nameservers from primary interface
get_nameservers() {
    ip route get 1.1.1.1 | awk '/via/ {print $3; exit}'
}

# if --clean and args > 0
if [ $# -gt 0 ] && [ "$1" = "--clean" ]; then
    echo "Cleaning up namespace $namespace"
    # bring down the namespace
    ip netns exec "$namespace" ip link set mv1 down 2> /dev/null

    # Bring down the macvlan interface
    ip link set mv1 down 2> /dev/null

    # Remove namespace
    ip netns del "$namespace" 2> /dev/null

    # Remove macvlan interface
    ip link del mv1 2> /dev/null

    exit 0
fi

# Add namespace
echo "Adding namespace $namespace"
ip netns add "$namespace"

# Wait for namespace creation
wait_for_namespace "$namespace"

# Create macvlan interface
echo "Creating macvlan interface mv1 with $primary_network_interface"
ip link add mv1 link $primary_network_interface type macvlan mode bridge

# Wait for interface creation
wait_for_interface "mv1"

# Add macvlan interface to namespace
echo "Adding macvlan interface to namespace"
ip link set mv1 netns "$namespace"

# # Wait for link creation in namespace
wait_for_link_creation "$namespace" "mv1"

# Bring up loopback interface
echo "Bringing up loopback interface"
ip netns exec "$namespace" ip link set dev lo up

# Get nameservers from primary interface
nameservers=$(get_nameservers)

# Configure custom resolv.conf for the namespace
echo "Configuring custom resolv.conf for the namespace $namespace with nameservers $nameservers"
mkdir -p "$(dirname "$custom_resolv_conf")"
echo "nameserver $nameservers" > "$custom_resolv_conf"

# Bring up macvlan interface
echo "Bringing up macvlan interface"
ip netns exec "$namespace" ip link set dev mv1 up

# Set IP address of with dhclient
echo "Setting IP address of macvlan interface with dhclient"
# pipe the output to nohup-ns-$namespace-dhclient.log
nohup ip netns exec "$namespace" dhclient mv1 > "nohup-ns-$namespace-dhclient.log" 2>&1 &
