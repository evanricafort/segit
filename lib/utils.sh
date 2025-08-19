# Function to display ASCII art banner
display_banner() {
    echo -e "${MAGENTA}"
    cat << "EOF"

▐▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▌
▐                                █████ ███████████ ███     ▌
▐                               ░░███ ░█░░░███░░░█░███     ▌
▐       █████   ██████   ███████ ░███ ░   ░███  ░ ░███     ▌
▐      ███░░   ███░░███ ███░░███ ░███     ░███    ░███     ▌
▐     ░░█████ ░███████ ░███ ░███ ░███     ░███    ░███     ▌
▐      ░░░░███░███░░░  ░███ ░███ ░███     ░███    ░░░      ▌
▐      ██████ ░░██████ ░░███████ █████    █████    ███     ▌
▐     ░░░░░░   ░░░░░░   ░░░░░███░░░░░    ░░░░░    ░░░      ▌
▐                       ███ ░███                           ▌
▐                      ░░██████                            ▌
▐                       ░░░░░░                             ▌
▐▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▌                      

                  by: evan (@evanricafort)      
              
EOF
    echo -e "${NC}" # Reset to no color
}

# Function to get and display the machine's IP addresses
get_ip_addresses() {
    echo -e "${CYAN}Retrieving machine's IP address(es)...${NC}"
    
    if command -v ip &> /dev/null; then
        IP_ADDRESSES=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1)
    elif command -v ifconfig &> /dev/null; then
        IP_ADDRESSES=$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}')
    else
        echo -e "${RED}Error:${NC} Neither 'ip' nor 'ifconfig' is installed. Cannot retrieve IP addresses."
        exit 1
    fi

    if [ -z "$IP_ADDRESSES" ]; then
        echo -e "${RED}Error:${NC} No active IPv4 addresses found on this machine."
        exit 1
    fi

    echo -e "${GREEN}Active IP address(es):${NC}"
    while read -r ip; do
        echo -e "  - ${YELLOW}$ip${NC}"
    done <<< "$IP_ADDRESSES"
    echo
}

# Function to check for required tools and root access
check_prerequisites() {
    REQUIRED_TOOLS=("nmap" "nc" "pandoc" "awk" "grep" "sort" "uniq")
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo -e "${RED}Error:${NC} Required tool '$tool' is not installed. Please install it and try again."
            exit 1
        fi
    done
}

# Function to check if the script is run as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root. Please run with sudo or as root user.${NC}"
        exit 1
    fi
}

# Function to consolidate targets from command line and file
consolidate_targets() {
    local targets="$1"
    local targets_file="$2"
    local all_targets_file="all_targets.txt"

    [ -f "$all_targets_file" ] && rm "$all_targets_file"
    
    # Write command line targets to the all targets file
    if [ -n "$targets" ]; then
        for target in $targets; do
            echo "$target" >> "$all_targets_file"
        done
    fi

    # Append targets from file
    if [ -n "$targets_file" ]; then
        if [ ! -f "$targets_file" ]; then
            echo -e "${RED}Error:${NC} Target file '$targets_file' not found."
            exit 1
        fi
        cat "$targets_file" >> "$all_targets_file"
    fi
    
    echo -e "${GREEN}All targets combined in ${YELLOW}$all_targets_file${NC}"
}

# Function to clean up temporary files
cleanup() {
    rm -f *.txt *.xml 2>/dev/null
    rm -rf "nmap_output_files" 2>/dev/null
}
