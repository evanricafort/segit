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

    mkdir -p "nmap_output_files"
    
    # TCP SYN Scan for open ports
    echo -e "${CYAN}Running TCP SYN scan (all ports)...${NC}"
    nmap -sS -p- -iL "$scan_input" $nmap_opts -oA "nmap_output_files/tcp_syn_scan"
    
    # TCP Connect Scan (fallback)
    echo -e "${CYAN}Running TCP Connect scan (all ports)...${NC}"
    nmap -sT -p- -iL "$scan_input" $nmap_opts -oA "nmap_output_files/tcp_connect_scan"

    # UDP Scan for open ports
    echo -e "${CYAN}Running UDP scan (top 100 ports)...${NC}"
    nmap -sU --top-ports 100 -iL "$scan_input" $nmap_opts -oA "nmap_output_files/udp_scan"
    
    # Version and Service Detection Scan on discovered ports
    echo -e "${CYAN}Running version and service detection scan on discovered ports...${NC}"
    nmap -sV -sC -iL "$scan_input" $nmap_opts -oA "nmap_output_files/service_scan"
    
    echo -e "${GREEN}All Nmap scans completed.${NC}"
}
