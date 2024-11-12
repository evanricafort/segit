#!/bin/bash

# Title: SegIt! - Automated Network Segmentation Testing Tool
# Author: Evan Ricafort (Portfolio - https://evanricafort.com | X - @evanricafort)
# Description: SegIt! is a shell script for automating networking segmentation test.

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display ASCII art banner
display_banner() {
    echo -e "${MAGENTA}"
    cat << "EOF"

                                                                                                                                     
   _|_|_|                         _|_|_|     _|       _|  
 _|           _|_|       _|_|_|     _|     _|_|_|_|   _|  
   _|_|     _|_|_|_|   _|    _|     _|       _|       _|  
       _|   _|         _|    _|     _|       _|           
 _|_|_|       _|_|_|     _|_|_|   _|_|_|       _|_|   _|  
                             _|                           
                         _|_|                             

                by: evan (@evanricafort)      

EOF
    echo -e "${NC}" # Reset to no color
}

# Function to get and display the machine's IP addresses
get_ip_addresses() {
    echo -e "${CYAN}Retrieving machine's IP address(es)...${NC}"
    # Using ip command to fetch non-loopback IPv4 addresses
    IP_ADDRESSES=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1)
    
    if [ -z "$IP_ADDRESSES" ]; then
        echo -e "${RED}Error:${NC} No active IPv4 addresses found on this machine."
        exit 1
    fi

    echo -e "${GREEN}Active IP address(es):${NC}"
    while read -r ip; do
        echo -e "  - ${YELLOW}$ip${NC}"
    done <<< "$IP_ADDRESSES"
    echo # Add an empty line for better readability
}

# Call the function to display the ASCII art banner
display_banner

# Function to display usage information
usage() {
    echo -e "${YELLOW}Usage:${NC} $0 [-f target_file] [-T4] [-open] <target(s)>"
    echo -e "${YELLOW}Example:${NC} $0 192.168.1.0/24"
    echo -e "         $0 -f targets.txt"
    echo -e "         $0 -T4 -f targets.txt"
    echo -e "         $0 -f targets.txt -T4 -open"
    exit 1
}

# Initialize variables
TARGETS=""
TARGETS_FILE=""
ADD_T4=0  # Flag to determine if -T4 should be added to Nmap commands
ADD_OPEN=0  # Flag to determine if --open should be added to Nmap commands
NETCAT_OUTPUT_FILE="netcat_verifications.txt"  # Output file for Netcat verifications

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -f|--file)
            if [ -n "$2" ]; then
                TARGETS_FILE="$2"
                shift 2
            else
                echo -e "${RED}Error:${NC} -f requires a filename"
                usage
            fi
            ;;
        -T4)
            ADD_T4=1
            shift
            ;;
        -open)
            ADD_OPEN=1
            shift
            ;;
        -*)
            echo -e "${RED}Unknown option:${NC} $1"
            usage
            ;;
        *)
            TARGETS="$TARGETS $1"
            shift
            ;;
    esac
done

# Check if target(s) are provided
if [ -z "$TARGETS" ] && [ -z "$TARGETS_FILE" ]; then
    usage
fi

# Check if target file exists
if [ -n "$TARGETS_FILE" ] && [ ! -f "$TARGETS_FILE" ]; then
    echo -e "${RED}Error:${NC} Target file '$TARGETS_FILE' not found."
    exit 1
fi

# Display machine's IP addresses only if targets are provided
get_ip_addresses

# Combine targets into a single file
ALL_TARGETS_FILE="all_targets.txt"
LIVE_HOSTS_FILE="live_hosts.txt"

# Remove previous files if they exist
if [ -f "$ALL_TARGETS_FILE" ]; then
    rm "$ALL_TARGETS_FILE"
fi

if [ -f "$LIVE_HOSTS_FILE" ]; then
    rm "$LIVE_HOSTS_FILE"
fi

# Write command line targets to the all targets file
if [ -n "$TARGETS" ]; then
    for target in $TARGETS; do
        echo "$target" >> "$ALL_TARGETS_FILE"
    done
fi

# Append targets from file to the all targets file
if [ -n "$TARGETS_FILE" ]; then
    cat "$TARGETS_FILE" >> "$ALL_TARGETS_FILE"
fi

echo -e "${CYAN}Scanning for live hosts in the target/s:${NC}"
cat "$ALL_TARGETS_FILE"
echo

# Check if nmap is installed
if ! command -v nmap &> /dev/null
then
    echo -e "${RED}Error:${NC} nmap is not installed. Please install it and try again."
    exit 1
fi

# Check if netcat is installed
if ! command -v nc &> /dev/null
then
    echo -e "${RED}Error:${NC} netcat (nc) is not installed. Please install it and try again."
    exit 1
fi

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root. Please run with sudo or as root user.${NC}"
    exit 1
fi

echo -e "${CYAN}Scanning for live hosts...${NC}"
if ! nmap -n -sn -iL "$ALL_TARGETS_FILE" -vv -oG live_hosts_nmap_output.txt; then
    echo -e "${RED}Error:${NC} Live host scan failed."
    # Proceeding even if nmap scan fails to allow scans on all targets
fi

# Extract live hosts from the nmap output
awk '/Up$/{print $2}' live_hosts_nmap_output.txt > "$LIVE_HOSTS_FILE"

# Determine scan input based on live hosts availability
if [ -s "$LIVE_HOSTS_FILE" ]; then
    echo -e "\n${GREEN}Live hosts found:${NC}"
    cat "$LIVE_HOSTS_FILE" | while read -r line; do echo -e "  - ${YELLOW}$line${NC}"; done
    SCAN_INPUT="$LIVE_HOSTS_FILE"
else
    echo -e "${RED}No live hosts found.${NC}\n"
    echo -e "${YELLOW}Proceeding to scan all targets.${NC}"
    SCAN_INPUT="$ALL_TARGETS_FILE"
fi

# End of Step 1
echo -e "\n${GREEN}Live hosts check completed.${NC}"

# Step 2: Perform port scanning
echo -e "\n${CYAN}Starting TCP SYN, TCP Connect and UDP Scan.${NC}"

# Define Nmap timing option if -T4 flag is set
TIMING_OPTION=""
if [ "$ADD_T4" -eq 1 ]; then
    TIMING_OPTION="-T4"
    echo -e "${BLUE}- Timing option (-T4) enabled for Nmap scans.${NC}"
fi

# Define Nmap open option if -open flag is set
OPEN_OPTION=""
if [ "$ADD_OPEN" -eq 1 ]; then
    OPEN_OPTION="--open"
    echo -e "${BLUE}- Open option (--open) enabled for Nmap scans.${NC}"
fi

TCP_SYN_SCAN="tcp_syn_scan.txt"
TCP_SYN_SCAN_GREPABLE="tcp_syn_scan_grep.txt"
TCP_CONNECT_SCAN="tcp_connect_scan.txt"
TCP_CONNECT_SCAN_GREPABLE="tcp_connect_scan_grep.txt"
UDP_SCAN="udp_scan.txt"
UDP_SCAN_GREPABLE="udp_scan_grep.txt"

echo -e "\n${CYAN}Performing TCP SYN scan on ${YELLOW}$(basename "$SCAN_INPUT")${NC}..."
if ! nmap -sS -p- -iL "$SCAN_INPUT" $TIMING_OPTION $OPEN_OPTION -vv -oN "$TCP_SYN_SCAN" -oG "$TCP_SYN_SCAN_GREPABLE"; then
    echo -e "${RED}Error:${NC} TCP SYN scan failed."
    # Continue to next scan instead of exiting
fi

echo -e "\n${CYAN}Performing TCP Connect scan on ${YELLOW}$(basename "$SCAN_INPUT")${NC}..."
if ! nmap -sT -p- -iL "$SCAN_INPUT" $TIMING_OPTION $OPEN_OPTION -vv -oN "$TCP_CONNECT_SCAN" -oG "$TCP_CONNECT_SCAN_GREPABLE"; then
    echo -e "${RED}Error:${NC} TCP Connect scan failed."
    # Continue to next scan instead of exiting
fi

echo -e "\n${CYAN}Performing UDP scan on ${YELLOW}$(basename "$SCAN_INPUT")${NC}..."
if ! nmap -sU -p- -iL "$SCAN_INPUT" $TIMING_OPTION $OPEN_OPTION -vv -oN "$UDP_SCAN" -oG "$UDP_SCAN_GREPABLE"; then
    echo -e "${RED}Error:${NC} UDP scan failed."
    # Continue to next scan instead of exiting
fi

# End of Step 2
echo -e "\n${GREEN}TCP SYN, TCP Connect, and UDP Scans completed.${NC}"

# Step 3: Extract open ports
extract_open_ports() {
    local scan_file="$1"
    local output_file="$2"

    # Remove output file if it exists
    if [ -f "$output_file" ]; then
        rm "$output_file"
    fi

    grep "/open/" "$scan_file" | while read -r line; do
        ip=$(echo "$line" | awk '{print $2}')
        ports=$(echo "$line" | awk -F"Ports: " '{print $2}' | tr ',' '\n' | grep "/open/" | awk -F'/' '{print $1}')
        for port in $ports; do
            echo "$ip $port" >> "$output_file"
        done
    done
}

# Extract open TCP ports
extract_open_ports "$TCP_SYN_SCAN_GREPABLE" "open_tcp_ports.txt"
extract_open_ports "$TCP_CONNECT_SCAN_GREPABLE" "open_tcp_ports_connect.txt"

# Combine TCP ports from all scans
cat open_tcp_ports.txt open_tcp_ports_connect.txt | sort -u > open_tcp_ports_combined.txt

# Extract open UDP ports
extract_open_ports "$UDP_SCAN_GREPABLE" "open_udp_ports.txt"

# Step 4: Test connections using netcat
echo -e "\n${CYAN}Starting netcat verifications.${NC}"

# Initialize the Netcat Output File
echo "Netcat Verification Results - $(date)" > "$NETCAT_OUTPUT_FILE"

echo -e "\n${CYAN}Testing open TCP ports with netcat...${NC}"
if [ -f "open_tcp_ports_combined.txt" ] && [ -s "open_tcp_ports_combined.txt" ]; then
    while read -r ip port; do
        echo -e "${MAGENTA}Testing TCP port ${YELLOW}$port${MAGENTA} on ${YELLOW}$ip${NC}"
        nc -vvv -w 2 "$ip" "$port" < /dev/null | tee -a tcp_netcat_results.txt "$NETCAT_OUTPUT_FILE"
    done < open_tcp_ports_combined.txt
else
    echo -e "${RED}No open TCP ports to test.${NC}\n"
fi

echo -e "\n${CYAN}Testing open UDP ports with netcat...${NC}"
if [ -f "open_udp_ports.txt" ] && [ -s "open_udp_ports.txt" ]; then
    while read -r ip port; do
        echo -e "${MAGENTA}Testing UDP port ${YELLOW}$port${MAGENTA} on ${YELLOW}$ip${NC}"
        nc -vvv -zu -w 2 "$ip" "$port" < /dev/null | tee -a udp_netcat_results.txt "$NETCAT_OUTPUT_FILE"
    done < open_udp_ports.txt
else
    echo -e "${RED}No open UDP ports to test.${NC}\n"
fi

# End of Step 4
echo -e "\n${GREEN}Netcat verifications completed.${NC}"

# Inform the user about the Netcat verification results file
echo -e "${GREEN}Netcat verification results have been saved to ${YELLOW}$NETCAT_OUTPUT_FILE${NC}."

echo -e "\n${GREEN}Overall network segmentation testing completed.${NC}"
