#!/bin/bash

# Title: SegIt! - Automated Network Segmentation Testing Toolkit
# Author: Evan Ricafort (Portfolio - https://evanricafort.com | X - @evanricafort)
# Description: SegIt! is a shell script for automating network segmentation tests.

# Source the configuration and utility files
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/config/colors.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/scan.sh"
source "$SCRIPT_DIR/lib/verify.sh"
source "$SCRIPT_DIR/lib/report.sh"
source "$SCRIPT_DIR/lib/discord.sh"

# Global variables
TARGETS=""
TARGETS_FILE=""
TRAFFIC_FROM="" 
CUSTOM_OUTPUT_DIR=""
COMPARE_MODE=0
NMAP_OPTS="-vv"
LIVE_HOSTS_FILE="live_hosts.txt"
SCAN_RESULTS_DIR="scan_results_$(date +%Y%m%d_%H%M%S)"
KEEP_FILES=0
DISCORD_WEBHOOK=""

# Record the start time
START_TIME=$(date +"%Y-%m-%d %H:%M:%S %Z")
START_SEC=$(date +%s)

# Display the ASCII art banner at the start
display_banner

# Function to display usage information
usage() {
    echo -e "${CYAN}Usage: $0 [options] <target(s) | -f <file>>${NC}"
    echo "  --from <subnet>    Define the source subnet (e.g., 10.1.42.0/24). [Optional: Auto-detected if omitted]"
    echo "  --o <dir>          Specify a custom output directory name"
    echo "  --cp               Run scan twice (Nmap + Verify) and compare results in the report"
    echo "  -f, --file <file>  Specify a file containing targets (one per line)"
    echo "  -T<0-5>            Set Nmap timing template (e.g., -T4)"
    echo "  --open             Only show open ports in Nmap output"
    echo "  --fast             Only scan the 1000 most common ports"
    echo "  --keep             Do not remove temporary files after scan completion"
    echo "  --discord          Send scan results to a Discord server"
    echo "  -h, --help         Display this help message"
    exit 1
}

# Check for prerequisites and root access
check_prerequisites
check_root

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --from)
            if [ -n "$2" ]; then
                TRAFFIC_FROM="$2"
                shift 2
            else
                echo -e "${RED}Error:${NC} --from requires a subnet."
                usage
            fi
            ;;
        --o)
            if [ -n "$2" ]; then
                CUSTOM_OUTPUT_DIR="$2"
                SCAN_RESULTS_DIR="$CUSTOM_OUTPUT_DIR"
                shift 2
            else
                echo -e "${RED}Error:${NC} --o requires a directory name."
                usage
            fi
            ;;
        --cp)
            COMPARE_MODE=1
            shift
            ;;
        -f|--file)
            if [ -n "$2" ]; then
                INPUT_FILE="$2"
                if [ -f "$INPUT_FILE" ]; then
                    TARGETS_FILE="$(realpath "$INPUT_FILE")"
                elif [ -f "$(pwd)/$INPUT_FILE" ]; then
                    TARGETS_FILE="$(pwd)/$INPUT_FILE"
                elif [ -f "$SCRIPT_DIR/$INPUT_FILE" ]; then
                    TARGETS_FILE="$SCRIPT_DIR/$INPUT_FILE"
                else
                    echo -e "${RED}Error:${NC} Target file '$INPUT_FILE' not found."
                    exit 1
                fi
                echo -e "${GREEN}Targets file loaded: ${YELLOW}$TARGETS_FILE${NC}"
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
        --keep)
            KEEP_FILES=1
            shift
            ;;
        --discord)
            if ! command -v curl &> /dev/null; then
                echo -e "${RED}Error:${NC} 'curl' is not installed."
                exit 1
            fi
            echo -e "${CYAN}Enter Discord Webhook URL:${NC}"
            read -r DISCORD_WEBHOOK
            if [ -z "$DISCORD_WEBHOOK" ]; then
                echo -e "${RED}Error:${NC} Webhook URL cannot be empty."
                exit 1
            fi
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

# Auto-detect TRAFFIC_FROM if not set
if [ -z "$TRAFFIC_FROM" ]; then
    echo -e "${YELLOW}No --from specified. Attempting to detect source subnet...${NC}"
    DEFAULT_IFACE=$(ip route show default | awk '/default/ {print $5}' | head -n1)
    if [ -n "$DEFAULT_IFACE" ]; then
        TRAFFIC_FROM=$(ip -o -f inet addr show dev "$DEFAULT_IFACE" | awk '{print $4}' | head -n1)
    fi
    if [ -z "$TRAFFIC_FROM" ]; then
        TRAFFIC_FROM=$(ip -o -f inet addr show | awk '!/127.0.0.1/ {print $4}' | head -n1)
    fi

    if [ -n "$TRAFFIC_FROM" ]; then
        echo -e "${GREEN}Detected Traffic From: ${YELLOW}$TRAFFIC_FROM${NC}"
    else
        echo -e "${RED}Error:${NC} Could not auto-detect source subnet. Specify with --from."
        usage
    fi
fi

if [ -z "$TARGETS" ] && [ -z "$TARGETS_FILE" ]; then
    usage
fi

# Create output directory
mkdir -p "$SCAN_RESULTS_DIR"
cd "$SCAN_RESULTS_DIR" || exit

get_ip_addresses
consolidate_targets "$TARGETS" "$TARGETS_FILE"
SCAN_INPUT="all_targets.txt"

# Step 1: Discover live hosts (Done once to define scope)
echo -e "\n${CYAN}Scanning for live hosts...${NC}"
scan_live_hosts "$SCAN_INPUT" "$LIVE_HOSTS_FILE"
if [ -s "$LIVE_HOSTS_FILE" ]; then
    SCAN_INPUT="$LIVE_HOSTS_FILE"
    echo -e "${GREEN}Live hosts found. Focusing scans on these hosts.${NC}"
else
    echo -e "${YELLOW}No live hosts found. Scanning all specified targets.${NC}"
fi

# Step 2 & 3: Run Scans and Verification (Conditional for Compare Mode)
if [ "$COMPARE_MODE" -eq 1 ]; then
    echo -e "\n${MAGENTA}=== Comparison Mode Enabled (2 Iterations) ===${NC}"
    
    # Run 1
    echo -e "\n${CYAN}[Run 1/2] Starting Nmap Scans...${NC}"
    run_nmap_scans "$SCAN_INPUT" "$NMAP_OPTS" "_run1"
    echo -e "\n${CYAN}[Run 1/2] Starting Verification...${NC}"
    verify_services "$TRAFFIC_FROM" "$SCAN_INPUT" "_run1"

    # Run 2
    echo -e "\n${CYAN}[Run 2/2] Starting Nmap Scans...${NC}"
    run_nmap_scans "$SCAN_INPUT" "$NMAP_OPTS" "_run2"
    echo -e "\n${CYAN}[Run 2/2] Starting Verification...${NC}"
    verify_services "$TRAFFIC_FROM" "$SCAN_INPUT" "_run2"

else
    # Standard Mode
    echo -e "\n${CYAN}Starting detailed port and service scans...${NC}"
    run_nmap_scans "$SCAN_INPUT" "$NMAP_OPTS" ""
    
    echo -e "\n${CYAN}Starting segmentation verification via netcat...${NC}"
    verify_services "$TRAFFIC_FROM" "$SCAN_INPUT" ""
fi

# Step 4: Generate HTML report
echo -e "\n${CYAN}Generating HTML report...${NC}"

END_TIME=$(date +"%Y-%m-%d %H:%M:%S %Z")
END_SEC=$(date +%s)
DURATION_SEC=$((END_SEC - START_SEC))
DURATION_HOURS=$((DURATION_SEC / 3600))
DURATION_MINUTES=$(((DURATION_SEC % 3600) / 60))
DURATION_SECONDS=$((DURATION_SEC % 60))
DURATION="${DURATION_HOURS}h ${DURATION_MINUTES}m ${DURATION_SECONDS}s"

# Pass all variables to report function
generate_html_report "$TARGETS" "$TARGETS_FILE" "$START_TIME" "$END_TIME" "$DURATION" "$TRAFFIC_FROM"
echo -e "${GREEN}Report generated successfully! Check: $(pwd)/SegIt_Report.html${NC}"

# Step 5: Discord
if [ -n "$DISCORD_WEBHOOK" ]; then
    echo -e "\n${CYAN}Archiving and sending to Discord...${NC}"
    send_to_discord "$DISCORD_WEBHOOK" "$SCAN_RESULTS_DIR" "$TARGETS" "$TARGETS_FILE" "$START_TIME" "$END_TIME" "$DURATION"
fi

# Step 6: Cleanup
if [ "$KEEP_FILES" -eq 0 ] && [ -z "$DISCORD_WEBHOOK" ]; then
    echo -e "\n${CYAN}Cleaning up temporary files...${NC}"
    cleanup
else
    echo -e "\n${YELLOW}Temporary files kept.${NC}"
fi
echo -e "${GREEN}Scan completed. Output in: $(pwd)${NC}"
