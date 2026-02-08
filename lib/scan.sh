# File: lib/scan.sh

# Function to perform live host discovery
scan_live_hosts() {
    local scan_input="$1"
    local live_hosts_file="$2"
    
    echo -e "${CYAN}Performing live host discovery...${NC}"
    nmap -n -sn -iL "$scan_input" -oG "live_hosts_nmap.gnmap"
    
    # Extract live hosts and ensure only unique IPs are listed
    awk '/Up$/{print $2}' "live_hosts_nmap.gnmap" | sort -u > "$live_hosts_file"
    
    echo -e "${GREEN}Live host discovery completed.${NC}"
}

# Function to run Nmap scans
run_nmap_scans() {
    local scan_input="$1"
    local nmap_opts="$2"
    local suffix="$3"

    # Create distinct directory for this run
    local output_dir="nmap_output_files${suffix}"
    mkdir -p "$output_dir"
    
    echo -e "${CYAN}Saving Nmap results to: ${YELLOW}$output_dir${NC}"

    # TCP SYN Scan
    echo -e "\n${CYAN}Running TCP SYN scan (all ports)...${NC}"
    nmap -sS -p- -iL "$scan_input" $nmap_opts -oA "${output_dir}/tcp_syn_scan"
    
    # TCP Connect Scan (fallback)
    echo -e "\n${CYAN}Running TCP Connect scan (all ports)...${NC}"
    nmap -sT -p- -iL "$scan_input" $nmap_opts -oA "${output_dir}/tcp_connect_scan"

    # UDP Scan
    echo -e "\n${CYAN}Running UDP scan (top 100 ports)...${NC}"
    nmap -sU --top-ports 100 -iL "$scan_input" $nmap_opts -oA "${output_dir}/udp_scan"
    
    # Version/Service Detection
    echo -e "\n${CYAN}Running version detection...${NC}"
    nmap -sV -sC -iL "$scan_input" $nmap_opts -oA "${output_dir}/service_scan"
    
    echo -e "${GREEN}Nmap scans completed for this iteration.${NC}"
}
