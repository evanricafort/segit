#!/bin/bash

# Title: SegIt! - Automated Network Segmentation Testing Tool
# Author: Gemini AI
# Description: SegIt! is a shell script for automating network segmentation tests.
# This script has been enhanced to be more modular and accurate.

# Source the configuration and utility files
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/config/colors.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/scan.sh"
source "$SCRIPT_DIR/lib/verify.sh"
source "$SCRIPT_DIR/lib/report.sh"

# Global variables
TARGETS=""
TARGETS_FILE=""
NMAP_OPTS="-vv"
LIVE_HOSTS_FILE="live_hosts.txt"
SCAN_RESULTS_DIR="scan_results_$(date +%Y%m%d_%H%M%S)"

# Display the ASCII art banner at the start
display_banner

# Function to display usage information
usage() {
    echo -e "${CYAN}Usage: $0 [options] <target 1 subnet> | -f <multiple subnet>${NC}"
    echo -e "${CYAN}Example: $0 -T4 --open 192.X.X.X/24${NC}"
    echo "  -f, --file <file>  Specify a file containing targets (one per line)"
    echo "  -T<0-5>            Set Nmap timing template (e.g., -T4)"
    echo "  --open             Only show open ports in Nmap output"
    echo "  --fast             Only scan the 1000 most common ports"
    echo "  -h, --help         Display this help message"
    exit 1
}

# Check for prerequisites and root access
check_prerequisites
check_root

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -f|--file)
            if [ -n "$2" ]; then
                TARGETS_FILE="$2"
                shift 2
            else
                echo -e "${RED}Error:${NC} -f requires a filename."
                usage
            fi
            ;;
        -T*)
            NMAP_OPTS+=" $1"
            shift
            ;;
        --open)
            NMAP_OPTS+=" --open"
            shift
            ;;
        --fast)
            NMAP_OPTS+=" --top-ports 1000"
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo -e "${RED}Unknown option:${NC} $1"
            usage
            ;;
        *)
            TARGETS+=" $1"
            shift
            ;;
    esac
done

# Check if targets are provided
if [ -z "$TARGETS" ] && [ -z "$TARGETS_FILE" ]; then
    usage
fi

# Create a directory to store scan results
mkdir -p "$SCAN_RESULTS_DIR"
cd "$SCAN_RESULTS_DIR" || exit

# Display machine's IP addresses
get_ip_addresses

# Consolidate targets
consolidate_targets "$TARGETS" "$TARGETS_FILE"
SCAN_INPUT="all_targets.txt"

# Step 1: Discover live hosts
echo -e "\n${CYAN}Scanning for live hosts...${NC}"
scan_live_hosts "$SCAN_INPUT" "$LIVE_HOSTS_FILE"
if [ -s "$LIVE_HOSTS_FILE" ]; then
    SCAN_INPUT="$LIVE_HOSTS_FILE"
    echo -e "${GREEN}Live hosts found. Focusing scans on these hosts.${NC}"
else
    echo -e "${YELLOW}No live hosts found. Scanning all specified targets.${NC}"
fi

# Step 2: Perform detailed port and service scanning
echo -e "\n${CYAN}Starting detailed port and service scans...${NC}"
run_nmap_scans "$SCAN_INPUT" "$NMAP_OPTS"

# Step 3: Perform advanced connection verification
echo -e "\n${CYAN}Starting advanced connection verifications...${NC}"
verify_services

# Step 4: Generate a comprehensive HTML report
echo -e "\n${CYAN}Generating a comprehensive HTML report...${NC}"
generate_html_report
echo -e "${GREEN}Report generated successfully! Check the output directory: $(pwd)${NC}"

# Clean up temporary files
echo -e "\n${CYAN}Cleaning up temporary files...${NC}"
cleanup
echo -e "${GREEN}Scan completed. The output is in: $(pwd)${NC}"
